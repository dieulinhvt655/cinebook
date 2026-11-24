package com.cinebook.showtime;

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
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * F4 on real PostgreSQL. Each test builds its own cinema and a small room:
 *
 * <pre>
 *   A: [A1 STD] [A2 STD]  aisle   [A4 STD]   (A5 exists but is inactive)
 *   B: [B1 COUPLE B2]     [B3 VIP] [B4 VIP]
 * </pre>
 *
 * so the result neither depends on nor disturbs the demo seed.
 */
@IntegrationTest
@AutoConfigureMockMvc
class SeatMapIT {

    static final int BASE_PRICE = 80000;

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
    long movie;
    long user;
    OffsetDateTime now;
    Map<String, Long> seat = new HashMap<>();

    @BeforeEach
    void setUp() {
        tag = UUID.randomUUID().toString().substring(0, 8);
        city = "Thành phố " + tag;
        now = OffsetDateTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.SECONDS);
        user = jdbc.queryForObject("""
                INSERT INTO users (email, password_hash, full_name) VALUES (?, 'x', 'Seat Map') RETURNING id
                """, Long.class, "seatmap-" + tag + "@test.dev");
        token = jwt.issueAccessToken(user, Role.CUSTOMER);
        long cinema = jdbc.queryForObject(
                "INSERT INTO cinemas (name, city, address) VALUES (?, ?, '1 Test') RETURNING id", Long.class,
                "Rạp " + tag, city);
        auditorium = jdbc.queryForObject(
                "INSERT INTO auditoriums (cinema_id, name, row_count, col_count) VALUES (?, 'P1', 2, 5) RETURNING id",
                Long.class, cinema);
        addSeat("A", 1, "STANDARD");
        addSeat("A", 2, "STANDARD");
        addSeat("A", 4, "STANDARD");
        addSeat("A", 5, "STANDARD");
        jdbc.update("UPDATE seats SET is_active = false WHERE id = ?", seat.get("A5"));
        addSeat("B", 1, "COUPLE");
        addSeat("B", 2, "COUPLE");
        jdbc.update("UPDATE seats SET pair_seat_id = ? WHERE id = ?", seat.get("B2"), seat.get("B1"));
        jdbc.update("UPDATE seats SET pair_seat_id = ? WHERE id = ?", seat.get("B1"), seat.get("B2"));
        addSeat("B", 3, "VIP");
        addSeat("B", 4, "VIP");
        movie = jdbc.queryForObject("""
                INSERT INTO movies (title, title_unaccent, duration_min, age_rating, release_date)
                VALUES (?, '', 100, 'T16', DATE '2026-01-01') RETURNING id
                """, Long.class, "Sơ Đồ Ghế " + tag);
    }

    @Test
    void seatMapNeedsALogin() throws Exception {
        mvc.perform(get("/showtimes/1/seats")).andExpect(status().isUnauthorized());
    }

    @Test
    void layoutTypesAndPricesFollowTheRoom() throws Exception {
        long id = showtime(now.plusHours(3));

        JsonNode body = seatMap(id);

        assertThat(body.get("showtimeId").asLong()).isEqualTo(id);
        assertThat(body.get("bookable").asBoolean()).isTrue();
        assertThat(body.get("basePrice").asInt()).isEqualTo(BASE_PRICE);
        assertThat(body.get("maxSeats").asInt()).isEqualTo(8);
        assertThat(body.get("movie").get("title").asText()).isEqualTo("Sơ Đồ Ghế " + tag);
        assertThat(body.get("movie").get("ageRating").asText()).isEqualTo("T16");
        JsonNode venue = body.get("venue");
        assertThat(venue.get("cinemaName").asText()).isEqualTo("Rạp " + tag);
        assertThat(venue.get("auditoriumName").asText()).isEqualTo("P1");
        assertThat(venue.get("colCount").asInt()).isEqualTo(5);
        assertThat(Duration.between(Instant.parse(body.get("serverTime").asText()), Instant.now()).abs())
                .isLessThan(Duration.ofMinutes(1));

        // Rows in order; the aisle (A3) and the inactive A5 are simply absent.
        assertThat(labels(body)).containsExactly("A1", "A2", "A4", "B1", "B2", "B3", "B4");

        Map<String, JsonNode> seats = seatsByLabel(body);
        assertThat(seats.get("A1").get("type").asText()).isEqualTo("STANDARD");
        assertThat(seats.get("A1").get("price").asInt()).isEqualTo(BASE_PRICE);
        assertThat(seats.get("B3").get("price").asInt()).isEqualTo(BASE_PRICE + 15000);
        assertThat(seats.get("B1").get("price").asInt()).isEqualTo(BASE_PRICE + 30000);
        assertThat(seats.get("B1").get("pairSeatId").asLong()).isEqualTo(seat.get("B2"));
        assertThat(seats.get("B2").get("pairSeatId").asLong()).isEqualTo(seat.get("B1"));
        assertThat(seats.get("A1").get("pairSeatId").isNull()).isTrue();

        List<String> typeCodes = new ArrayList<>();
        body.get("seatTypes").forEach(t -> typeCodes.add(t.get("code").asText()));
        assertThat(typeCodes).containsExactly("STANDARD", "VIP", "COUPLE");
        assertThat(body.get("seatTypes").get(2).get("price").asInt()).isEqualTo(BASE_PRICE + 30000);
        assertThat(body.get("seatTypes").get(2).get("seatsPerUnit").asInt()).isEqualTo(2);
    }

    @Test
    void statusComesFromLiveBookingsAndExpiredHoldsCountAsFree() throws Exception {
        long id = showtime(now.plusHours(3));
        booking(id, "PAID", now.plusMinutes(5), true, "A1");
        booking(id, "HOLDING", now.plusMinutes(5), true, "B1", "B2");
        // Expired but not yet swept by HoldExpiryJob: already free for readers.
        booking(id, "HOLDING", now.minusMinutes(1), true, "A2");
        // Cancelled earlier: its rows were released.
        booking(id, "CANCELLED", now.minusMinutes(1), false, "B3");
        // Same seat sold for another showtime must not leak into this one.
        booking(showtime(now.plusDays(2)), "PAID", now.plusMinutes(5), true, "A4");

        JsonNode body = seatMap(id);
        Map<String, JsonNode> seats = seatsByLabel(body);
        assertThat(seats.get("A1").get("status").asText()).isEqualTo("SOLD");
        assertThat(seats.get("B1").get("status").asText()).isEqualTo("HELD");
        assertThat(seats.get("B2").get("status").asText()).isEqualTo("HELD");
        assertThat(seats.get("A2").get("status").asText()).isEqualTo("AVAILABLE");
        assertThat(seats.get("B3").get("status").asText()).isEqualTo("AVAILABLE");
        assertThat(seats.get("A4").get("status").asText()).isEqualTo("AVAILABLE");
        assertThat(seats.get("B4").get("status").asText()).isEqualTo("AVAILABLE");
        assertThat(body.get("availableCount").asInt()).isEqualTo(4);

        // S07 shows the same count under the time chip.
        String day = now.plusHours(3).atZoneSameInstant(VietnamTime.ZONE).toLocalDate().toString();
        JsonNode s07 = json.readTree(mvc.perform(auth(get("/movies/{id}/showtimes", movie)
                        .param("date", day).param("city", city)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        JsonNode slot = s07.get("cinemas").get(0).get("showtimes").get(0);
        assertThat(slot.get("id").asLong()).isEqualTo(id);
        assertThat(slot.get("availableSeats").asInt()).isEqualTo(4);
    }

    @Test
    void showtimeInsideTheSalesCutoffIsReturnedButNotBookable() throws Exception {
        long closing = showtime(now.plusMinutes(10));
        long started = showtime(now.minusMinutes(30));

        assertThat(seatMap(closing).get("bookable").asBoolean()).isFalse();
        assertThat(seatMap(started).get("bookable").asBoolean()).isFalse();
    }

    @Test
    void missingCancelledOrHiddenShowtimesAre404() throws Exception {
        long cancelled = showtime(now.plusHours(3));
        jdbc.update("UPDATE showtimes SET status = 'CANCELLED' WHERE id = ?", cancelled);
        long hiddenMovie = showtime(now.plusHours(6));

        notFound(cancelled);
        notFound(Long.MAX_VALUE);

        seatMap(hiddenMovie);
        jdbc.update("UPDATE movies SET is_active = false WHERE id = ?", movie);
        notFound(hiddenMovie);

        mvc.perform(auth(get("/showtimes/abc/seats"))).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    private void addSeat(String row, int col, String type) {
        seat.put(row + col, jdbc.queryForObject("""
                INSERT INTO seats (auditorium_id, row_label, col_number, seat_type_id)
                SELECT ?, ?, ?, id FROM seat_types WHERE code = ? RETURNING id
                """, Long.class, auditorium, row, col, type));
    }

    private long showtime(OffsetDateTime start) {
        return jdbc.queryForObject("""
                INSERT INTO showtimes (movie_id, auditorium_id, start_at, end_at, format, subtitle, base_price)
                VALUES (?, ?, ?, ?, '2D', 'SUB', ?) RETURNING id
                """, Long.class, movie, auditorium, start, start.plus(Duration.ofMinutes(5)), BASE_PRICE);
    }

    private void booking(long showtimeId, String status, OffsetDateTime expiresAt, boolean active, String... labels) {
        long id = jdbc.queryForObject("""
                INSERT INTO bookings (booking_code, user_id, showtime_id, status, seat_total, total_amount, expires_at)
                VALUES (?, ?, ?, ?, 0, 0, ?) RETURNING id
                """, Long.class, UUID.randomUUID().toString().substring(0, 12), user, showtimeId, status, expiresAt);
        for (String label : labels) {
            jdbc.update("""
                    INSERT INTO booking_seats (booking_id, showtime_id, seat_id, seat_type_code, price, is_active)
                    VALUES (?, ?, ?, 'STANDARD', 1, ?)
                    """, id, showtimeId, seat.get(label), active);
        }
    }

    private JsonNode seatMap(long showtimeId) throws Exception {
        return json.readTree(mvc.perform(auth(get("/showtimes/{id}/seats", showtimeId)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
    }

    private void notFound(long showtimeId) throws Exception {
        mvc.perform(auth(get("/showtimes/{id}/seats", showtimeId))).andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"));
    }

    private MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder req) {
        return req.header("Authorization", "Bearer " + token);
    }

    private static List<String> labels(JsonNode body) {
        List<String> labels = new ArrayList<>();
        body.get("rows").forEach(r -> r.get("seats").forEach(s -> labels.add(s.get("row").asText() + s.get("col"))));
        return labels;
    }

    private static Map<String, JsonNode> seatsByLabel(JsonNode body) {
        Map<String, JsonNode> seats = new HashMap<>();
        body.get("rows").forEach(r -> r.get("seats").forEach(s -> seats.put(s.get("row").asText() + s.get("col"), s)));
        return seats;
    }
}
