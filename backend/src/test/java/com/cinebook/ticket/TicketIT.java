package com.cinebook.ticket;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.cinebook.booking.ComboService;
import com.cinebook.booking.PaymentService;
import com.cinebook.booking.SeatHoldService;
import com.cinebook.booking.dto.ComboItem;
import com.cinebook.booking.dto.HoldRequest;
import com.cinebook.booking.dto.PaymentRequest;
import com.cinebook.security.JwtService;
import com.cinebook.security.Role;
import com.cinebook.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
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

/** F7 on real PostgreSQL. Each test builds its own room, users and paid bookings. */
@IntegrationTest
@AutoConfigureMockMvc
class TicketIT {

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper json;

    @Autowired
    JdbcTemplate jdbc;

    @Autowired
    JwtService jwt;

    @Autowired
    SeatHoldService holds;

    @Autowired
    ComboService combos;

    @Autowired
    PaymentService payments;

    @Autowired
    QrSigner qr;

    String tag;
    long alice;
    long bob;
    long auditorium;
    long movie;
    List<Long> seats = new ArrayList<>();
    OffsetDateTime now;

    @BeforeEach
    void setUp() {
        tag = UUID.randomUUID().toString().substring(0, 8);
        now = OffsetDateTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.SECONDS);
        alice = user("alice");
        bob = user("bob");
        long cinema = jdbc.queryForObject(
                "INSERT INTO cinemas (name, city, address) VALUES (?, ?, '1 Test') RETURNING id", Long.class,
                "Rạp " + tag, "Thành phố " + tag);
        auditorium = jdbc.queryForObject(
                "INSERT INTO auditoriums (cinema_id, name, row_count, col_count) VALUES (?, 'P1', 1, 4) RETURNING id",
                Long.class, cinema);
        for (int col = 1; col <= 4; col++) {
            seats.add(jdbc.queryForObject("""
                    INSERT INTO seats (auditorium_id, row_label, col_number, seat_type_id)
                    SELECT ?, 'A', ?, id FROM seat_types WHERE code = 'STANDARD' RETURNING id
                    """, Long.class, auditorium, col));
        }
        movie = jdbc.queryForObject("""
                INSERT INTO movies (title, title_unaccent, duration_min, age_rating, release_date)
                VALUES (?, '', 100, 'T16', DATE '2026-01-01') RETURNING id
                """, Long.class, "Vé " + tag);
    }

    @Test
    void upcomingAndPastAreSplitByShowtimeEndNewestPurchaseFirst() throws Exception {
        long first = paid(alice, now.plusHours(3), 0, 1);
        long second = paid(alice, now.plusHours(6), 0, 1);
        long watched = paid(alice, now.plusHours(9), 2, 3);
        moveShowtime(watched, now.minusHours(5));
        holds.hold(alice, new HoldRequest(showtime(now.plusHours(12)), List.of(seats.get(0), seats.get(1))));

        JsonNode upcoming = body(ok(get("/me/tickets"), alice));
        assertThat(ids(upcoming)).containsExactly(second, first);
        assertThat(upcoming.get(0).get("seats").toString()).isEqualTo("[\"A1\",\"A2\"]");
        assertThat(upcoming.get(0).get("show").get("movieTitle").asText()).isEqualTo("Vé " + tag);

        assertThat(ids(body(ok(get("/me/tickets").param("scope", "PAST"), alice)))).containsExactly(watched);
        assertThat(ids(body(ok(get("/me/tickets"), bob)))).doesNotContain(first, second, watched);
    }

    @Test
    void detailIsTheOwnersStubWithASignedQr() throws Exception {
        long combo = jdbc.queryForObject("INSERT INTO combos (name, price) VALUES (?, 50000) RETURNING id",
                Long.class, "Combo " + tag);
        long id = hold(alice, now.plusHours(3), 0, 1);
        combos.replace(alice, id, List.of(new ComboItem(combo, 2)));
        pay(alice, id);

        JsonNode t = body(ok(get("/tickets/{id}", id), alice));
        String code = t.get("bookingCode").asText();
        assertThat(qr.verify(t.get("qrPayload").asText())).contains(code);
        assertThat(t.get("upcoming").asBoolean()).isTrue();
        assertThat(t.get("seats")).hasSize(2);
        t.get("seats").forEach(s -> {
            assertThat(s.get("ticketCode").asText()).matches("TK[A-Z2-9]{10}");
            assertThat(s.get("status").asText()).isEqualTo("VALID");
        });
        assertThat(t.get("combos").get(0).get("quantity").asInt()).isEqualTo(2);
        assertThat(t.get("totalAmount").asInt())
                .isEqualTo(t.get("seatTotal").asInt() + 100000);

        // Someone else's ticket, an unpaid hold and a missing id all look the same.
        mvc.perform(auth(get("/tickets/{id}", id), bob)).andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"));
        long unpaid = hold(alice, now.plusHours(6), 2, 3);
        mvc.perform(auth(get("/tickets/{id}", unpaid), alice)).andExpect(status().isNotFound());
    }

    @Test
    void anUnknownScopeIs400() throws Exception {
        mvc.perform(auth(get("/me/tickets").param("scope", "SOON"), alice)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        mvc.perform(get("/me/tickets")).andExpect(status().isUnauthorized());
    }

    /** S14 history lives next to the tickets because it reads the same paid bookings plus the rest. */
    @Test
    void historyListsEveryStatusNewestFirstForItsOwnerOnly() throws Exception {
        long paidId = paid(alice, now.plusHours(3), 0, 1);
        long cancelled = hold(alice, now.plusHours(6), 0, 1);
        holds.cancel(alice, cancelled);
        long lapsed = hold(alice, now.plusHours(9), 2);
        jdbc.update("UPDATE bookings SET expires_at = now() - interval '1 minute' WHERE id = ?", lapsed);
        long holding = hold(alice, now.plusHours(12), 3);

        JsonNode history = body(ok(get("/me/bookings"), alice));
        assertThat(ids(history)).containsExactly(holding, lapsed, cancelled, paidId);
        List<String> statuses = new ArrayList<>();
        history.forEach(b -> statuses.add(b.get("status").asText()));
        assertThat(statuses).containsExactly("HOLDING", "EXPIRED", "CANCELLED", "PAID");
        assertThat(history.get(2).get("seats").toString()).isEqualTo("[\"A1\",\"A2\"]");
        assertThat(history.get(2).get("paidAt").isNull()).isTrue();
        assertThat(history.get(3).get("paidAt").isNull()).isFalse();
        assertThat(history.get(3).get("show").get("movieTitle").asText()).isEqualTo("Vé " + tag);
        assertThat(history.get(3).get("totalAmount").asInt()).isPositive();

        assertThat(body(ok(get("/me/bookings"), bob))).isEmpty();
        mvc.perform(get("/me/bookings")).andExpect(status().isUnauthorized());
    }

    private long paid(long userId, OffsetDateTime start, int... seatIndexes) {
        long id = hold(userId, start, seatIndexes);
        pay(userId, id);
        return id;
    }

    private long hold(long userId, OffsetDateTime start, int... seatIndexes) {
        List<Long> ids = new ArrayList<>();
        for (int i : seatIndexes) {
            ids.add(seats.get(i));
        }
        return holds.hold(userId, new HoldRequest(showtime(start), ids)).id();
    }

    private void pay(long userId, long bookingId) {
        payments.pay(userId, bookingId, "k-" + UUID.randomUUID(), PaymentRequest.Result.SUCCESS);
    }

    private long showtime(OffsetDateTime start) {
        return jdbc.queryForObject("""
                INSERT INTO showtimes (movie_id, auditorium_id, start_at, end_at, format, subtitle, base_price)
                VALUES (?, ?, ?, ?, '2D', 'SUB', 80000) RETURNING id
                """, Long.class, movie, auditorium, start, start.plus(Duration.ofHours(2)));
    }

    private void moveShowtime(long bookingId, OffsetDateTime start) {
        jdbc.update("""
                UPDATE showtimes SET start_at = ?, end_at = ?
                 WHERE id = (SELECT showtime_id FROM bookings WHERE id = ?)
                """, start, start.plus(Duration.ofHours(2)), bookingId);
    }

    private long user(String name) {
        return jdbc.queryForObject("""
                INSERT INTO users (email, password_hash, full_name) VALUES (?, 'x', ?) RETURNING id
                """, Long.class, name + "-" + tag + "@test.dev", name);
    }

    private MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder req, long userId) {
        return req.header("Authorization", "Bearer " + jwt.issueAccessToken(userId, Role.CUSTOMER));
    }

    private ResultActions ok(MockHttpServletRequestBuilder req, long userId) throws Exception {
        return mvc.perform(auth(req, userId)).andExpect(status().isOk());
    }

    private JsonNode body(ResultActions result) throws Exception {
        return json.readTree(result.andReturn().getResponse().getContentAsString());
    }

    private static List<Long> ids(JsonNode list) {
        List<Long> ids = new ArrayList<>();
        list.forEach(n -> ids.add(n.get("id").asLong()));
        return ids;
    }
}
