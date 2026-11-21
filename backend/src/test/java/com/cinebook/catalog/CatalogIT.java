package com.cinebook.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.cinebook.common.VietnamTime;
import com.cinebook.security.JwtService;
import com.cinebook.security.Role;
import com.cinebook.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * F2/F3 acceptance criteria on real PostgreSQL. Each test builds its own cinema (unique city) and
 * movies with showtimes relative to now, so it neither depends on nor disturbs the demo seed.
 */
@IntegrationTest
@AutoConfigureMockMvc
class CatalogIT {

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper json;

    @Autowired
    JdbcTemplate jdbc;

    @Autowired
    JwtService jwt;

    String token;
    String tag;
    String city;
    long auditorium;
    OffsetDateTime now;

    @BeforeEach
    void setUp() {
        token = jwt.issueAccessToken(1, Role.CUSTOMER);
        tag = UUID.randomUUID().toString().substring(0, 8);
        city = "Thành phố " + tag;
        now = OffsetDateTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.SECONDS);
        long cinema = jdbc.queryForObject(
                "INSERT INTO cinemas (name, city, address) VALUES (?, ?, '1 Test') RETURNING id", Long.class,
                "Rạp " + tag, city);
        auditorium = jdbc.queryForObject(
                "INSERT INTO auditoriums (cinema_id, name, row_count, col_count) VALUES (?, 'P1', 1, 1) RETURNING id",
                Long.class, cinema);
    }

    @Test
    void catalogNeedsALogin() throws Exception {
        mvc.perform(get("/movies")).andExpect(status().isUnauthorized());
    }

    @Test
    void nowShowingNeedsReleaseAndAShowtimeWithinSevenDays() throws Exception {
        LocalDate today = VietnamTime.today(java.time.Clock.systemUTC());
        long showing = movie("Đang Chiếu " + tag, today.minusDays(3));
        showtime(showing, now.plusHours(3));
        long noShowtimes = movie("Không Suất " + tag, today.minusDays(3));
        long onlyFar = movie("Suất Xa " + tag, today.minusDays(3));
        showtime(onlyFar, now.plusDays(9));
        long soon = movie("Sắp Chiếu " + tag, today.plusDays(10));

        List<Long> nowIds = ids(perform(get("/movies").param("status", "NOW_SHOWING")));
        assertThat(nowIds).contains(showing).doesNotContain(noShowtimes, onlyFar, soon);

        List<Long> defaultIds = ids(perform(get("/movies")));
        assertThat(defaultIds).contains(showing).doesNotContain(soon);

        List<Long> soonIds = ids(perform(get("/movies").param("status", "COMING_SOON")));
        assertThat(soonIds).contains(soon).doesNotContain(showing, noShowtimes);
    }

    @Test
    void searchIgnoresAccentsAndCaseAndCoversBothTabs() throws Exception {
        LocalDate today = VietnamTime.today(java.time.Clock.systemUTC());
        long released = movie("Đất Rừng Phương Nam " + tag, today.minusDays(1));
        long upcoming = movie("ĐẤT RỪNG Trở Lại " + tag, today.plusDays(5));

        List<Long> found = ids(perform(get("/movies").param("q", "  dat rung ")));
        assertThat(found).contains(released, upcoming);

        assertThat(ids(perform(get("/movies").param("q", "dat rung").param("status", "COMING_SOON"))))
                .contains(upcoming).doesNotContain(released);

        perform(get("/movies").param("q", "zzz-không-có-" + tag)).andExpect(jsonPath("$.length()").value(0));
        // % is a literal character, not a wildcard
        perform(get("/movies").param("q", "%")).andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void seededSearchFindsAvengers() throws Exception {
        perform(get("/movies").param("q", "avengers"))
                .andExpect(jsonPath("$[0].title").value("Avengers of the Abyss"));
    }

    @Test
    void detailIncludesGenresAndHidesInactiveMovies() throws Exception {
        long id = movie("Chi Tiết " + tag, LocalDate.of(2026, 1, 1));
        jdbc.update("INSERT INTO genres (name) VALUES (?)", "Thể loại " + tag);
        jdbc.update("INSERT INTO movie_genres (movie_id, genre_id) SELECT ?, id FROM genres WHERE name = ?", id,
                "Thể loại " + tag);

        perform(get("/movies/{id}", id))
                .andExpect(jsonPath("$.title").value("Chi Tiết " + tag))
                .andExpect(jsonPath("$.ageRating").value("T13"))
                .andExpect(jsonPath("$.durationMin").value(100))
                .andExpect(jsonPath("$.trailerUrl").value("https://www.youtube.com/watch?v=test"))
                .andExpect(jsonPath("$.genres[0]").value("Thể loại " + tag));

        jdbc.update("UPDATE movies SET is_active = false WHERE id = ?", id);
        mvc.perform(auth(get("/movies/{id}", id))).andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"));
        mvc.perform(auth(get("/movies/{id}/showtimes", id))).andExpect(status().isNotFound());
    }

    @Test
    void showtimesAreGroupedByCinemaHideStartedAndCloseSales15MinutesBefore() throws Exception {
        long id = movie("Lịch Chiếu " + tag, LocalDate.of(2026, 1, 1));
        OffsetDateTime closing = now.plusMinutes(10);
        OffsetDateTime open = now.plusHours(2);
        showtime(id, now.minusMinutes(30)); // started: hidden
        long closingId = showtime(id, closing);
        long openId = showtime(id, open);

        // Both slots on the same Vietnam day unless the test runs right before midnight.
        LocalDate day = closing.atZoneSameInstant(VietnamTime.ZONE).toLocalDate();
        JsonNode body = body(perform(get("/movies/{id}/showtimes", id).param("date", day.toString())
                .param("city", city)));

        assertThat(body.get("date").asText()).isEqualTo(day.toString());
        assertThat(body.get("cinemas")).hasSize(1);
        JsonNode cinema = body.get("cinemas").get(0);
        assertThat(cinema.get("name").asText()).isEqualTo("Rạp " + tag);
        List<Long> slotIds = new ArrayList<>();
        cinema.get("showtimes").forEach(s -> {
            slotIds.add(s.get("id").asLong());
            if (s.get("id").asLong() == closingId) {
                assertThat(s.get("bookable").asBoolean()).isFalse();
            } else {
                assertThat(s.get("bookable").asBoolean()).isTrue();
                assertThat(s.get("basePrice").asInt()).isEqualTo(80000);
                assertThat(s.get("format").asText()).isEqualTo("2D");
            }
        });
        if (open.atZoneSameInstant(VietnamTime.ZONE).toLocalDate().equals(day)) {
            assertThat(slotIds).containsExactly(closingId, openId);
        } else {
            assertThat(slotIds).containsExactly(closingId);
        }
        assertThat(body.get("nextAvailableDate").isNull()).isTrue();
    }

    @Test
    void emptyDaySuggestsTheNextDateWithShowtimes() throws Exception {
        long id = movie("Ngày Trống " + tag, LocalDate.of(2026, 1, 1));
        OffsetDateTime later = now.plusDays(3);
        showtime(id, later);
        LocalDate today = VietnamTime.today(java.time.Clock.systemUTC());

        JsonNode body = body(perform(get("/movies/{id}/showtimes", id).param("date", today.toString())
                .param("city", city)));
        assertThat(body.get("cinemas")).isEmpty();
        assertThat(body.get("nextAvailableDate").asText())
                .isEqualTo(later.atZoneSameInstant(VietnamTime.ZONE).toLocalDate().toString());

        // Another city has nothing for this movie at all
        JsonNode other = body(perform(get("/movies/{id}/showtimes", id).param("city", "Không có " + tag)));
        assertThat(other.get("cinemas")).isEmpty();
        assertThat(other.get("nextAvailableDate").isNull()).isTrue();
    }

    @Test
    void invalidParametersAre400WithACode() throws Exception {
        mvc.perform(auth(get("/movies").param("status", "FOO"))).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fields.status").exists());
        mvc.perform(auth(get("/movies/1/showtimes").param("date", "21-11-2026")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    private long movie(String title, LocalDate release) {
        return jdbc.queryForObject("""
                INSERT INTO movies (title, title_unaccent, description, duration_min, age_rating, release_date,
                                    language, trailer_url)
                VALUES (?, '', 'Mô tả', 100, 'T13', ?, 'Tiếng Việt', 'https://www.youtube.com/watch?v=test')
                RETURNING id
                """, Long.class, title, release);
    }

    private long showtime(long movieId, OffsetDateTime start) {
        return jdbc.queryForObject("""
                INSERT INTO showtimes (movie_id, auditorium_id, start_at, end_at, format, subtitle, base_price)
                VALUES (?, ?, ?, ?, '2D', 'SUB', 80000) RETURNING id
                """, Long.class, movieId, auditorium, start, start.plus(Duration.ofMinutes(5)));
    }

    private MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder req) {
        return req.header("Authorization", "Bearer " + token);
    }

    private ResultActions perform(MockHttpServletRequestBuilder req) throws Exception {
        return mvc.perform(auth(req)).andExpect(status().isOk());
    }

    private JsonNode body(ResultActions result) throws Exception {
        return json.readTree(result.andReturn().getResponse().getContentAsString());
    }

    private List<Long> ids(ResultActions result) throws Exception {
        List<Long> ids = new ArrayList<>();
        body(result).forEach(m -> ids.add(m.get("id").asLong()));
        return ids;
    }
}
