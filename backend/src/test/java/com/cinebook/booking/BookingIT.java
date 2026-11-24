package com.cinebook.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.cinebook.booking.dto.HoldRequest;
import com.cinebook.common.ApiException;
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
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/**
 * F5 on real PostgreSQL. Each test builds its own room:
 *
 * <pre>
 *   A: [A1] [A2] [A3] [A4]   aisle   [A6]
 *   B: [B1 COUPLE B2] [B3 VIP]
 * </pre>
 */
@IntegrationTest
@AutoConfigureMockMvc
class BookingIT {

    static final int BASE_PRICE = 80000;

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
    HoldExpiryService expiry;

    String tag;
    long alice;
    long bob;
    long auditorium;
    long movie;
    long showtime;
    OffsetDateTime now;
    Map<String, Long> seat = new HashMap<>();

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
                "INSERT INTO auditoriums (cinema_id, name, row_count, col_count) VALUES (?, 'P1', 2, 6) RETURNING id",
                Long.class, cinema);
        for (int col : new int[] {1, 2, 3, 4, 6}) {
            addSeat("A", col, "STANDARD");
        }
        addSeat("B", 1, "COUPLE");
        addSeat("B", 2, "COUPLE");
        jdbc.update("UPDATE seats SET pair_seat_id = ? WHERE id = ?", seat.get("B2"), seat.get("B1"));
        jdbc.update("UPDATE seats SET pair_seat_id = ? WHERE id = ?", seat.get("B1"), seat.get("B2"));
        addSeat("B", 3, "VIP");
        movie = jdbc.queryForObject("""
                INSERT INTO movies (title, title_unaccent, duration_min, age_rating, release_date)
                VALUES (?, '', 100, 'P', DATE '2026-01-01') RETURNING id
                """, Long.class, "Giữ Ghế " + tag);
        showtime = showtime(now.plusHours(3));
    }

    @Test
    void holdNeedsALogin() throws Exception {
        mvc.perform(post("/bookings").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void holdFixesPricesForTenMinutesAndTheSeatsShowAsHeld() throws Exception {
        JsonNode body = json.readTree(hold(alice, "A1", "A2", "B1", "B2", "B3")
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString());

        int std = BASE_PRICE + surcharge("STANDARD");
        int couple = BASE_PRICE + surcharge("COUPLE");
        int vip = BASE_PRICE + surcharge("VIP");
        assertThat(body.get("status").asText()).isEqualTo("HOLDING");
        assertThat(body.get("bookingCode").asText()).matches("CB[A-Z2-9]{6}");
        assertThat(body.get("seatTotal").asInt()).isEqualTo(2 * std + 2 * couple + vip);
        assertThat(body.get("totalAmount").asInt()).isEqualTo(body.get("seatTotal").asInt());
        List<String> labels = new ArrayList<>();
        body.get("seats").forEach(s -> labels.add(s.get("label").asText()));
        assertThat(labels).containsExactly("A1", "A2", "B1", "B2", "B3");
        Instant expires = Instant.parse(body.get("expiresAt").asText());
        Instant server = Instant.parse(body.get("serverTime").asText());
        assertThat(Duration.between(server, expires)).isBetween(Duration.ofMinutes(10).minusSeconds(2),
                Duration.ofMinutes(10).plusSeconds(1));

        JsonNode map = json.readTree(mvc.perform(get("/showtimes/{id}/seats", showtime)
                .header("Authorization", bearer(bob))).andReturn().getResponse().getContentAsString());
        assertThat(map.get("availableCount").asInt()).isEqualTo(2);
    }

    @Test
    void twoUsersHoldingTheSameSeatAtOnceOnlyOneWins() throws Exception {
        int rounds = 5;
        for (int round = 0; round < rounds; round++) {
            long st = showtime(now.plusHours(4 + round));
            CountDownLatch start = new CountDownLatch(1);
            ExecutorService pool = Executors.newFixedThreadPool(2);
            try {
                Callable<String> asAlice = () -> {
                    start.await();
                    return tryHold(alice, st);
                };
                Callable<String> asBob = () -> {
                    start.await();
                    return tryHold(bob, st);
                };
                Future<String> a = pool.submit(asAlice);
                Future<String> b = pool.submit(asBob);
                start.countDown();
                List<String> results = Stream.of(a.get(), b.get()).sorted().toList();
                assertThat(results).containsExactly("OK", "SEAT_TAKEN");
                assertThat(jdbc.queryForObject("""
                        SELECT count(*) FROM booking_seats WHERE showtime_id = ? AND is_active
                        """, Integer.class, st)).isEqualTo(2);
            } finally {
                pool.shutdownNow();
            }
        }
    }

    @Test
    void aSeatHeldBySomeoneElseIs409WithAClearMessage() throws Exception {
        hold(alice, "A3", "A4").andExpect(status().isCreated());

        hold(bob, "A4").andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("SEAT_TAKEN"))
                .andExpect(jsonPath("$.detail").value(SeatHoldService.SEAT_TAKEN_MESSAGE));
    }

    @Test
    void expiredHoldsFreeTheSeatsEvenBeforeTheJobRuns() throws Exception {
        long id = bookingId(hold(alice, "A1", "A2"));
        jdbc.update("UPDATE bookings SET expires_at = ? WHERE id = ?", now.minusSeconds(1), id);

        mvc.perform(get("/bookings/{id}", id).header("Authorization", bearer(alice)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("EXPIRED"));
        hold(bob, "A1", "A2").andExpect(status().isCreated());
        assertThat(jdbc.queryForObject("SELECT status FROM bookings WHERE id = ?", String.class, id))
                .isEqualTo("EXPIRED");
    }

    @Test
    void expiryJobReleasesOverdueHolds() throws Exception {
        long id = bookingId(hold(alice, "A1", "A2"));
        jdbc.update("UPDATE bookings SET expires_at = ? WHERE id = ?", now.minusSeconds(1), id);

        assertThat(expiry.expireOverdueHolds()).isGreaterThanOrEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT status FROM bookings WHERE id = ?", String.class, id))
                .isEqualTo("EXPIRED");
        assertThat(jdbc.queryForObject("SELECT count(*) FROM booking_seats WHERE booking_id = ? AND is_active",
                Integer.class, id)).isZero();
    }

    @Test
    void cancellingReleasesAtOnceAndOnlyTheOwnerMayCancel() throws Exception {
        long id = bookingId(hold(alice, "A1", "A2"));

        mvc.perform(delete("/bookings/{id}", id).header("Authorization", bearer(bob)))
                .andExpect(status().isNotFound());
        mvc.perform(get("/bookings/{id}", id).header("Authorization", bearer(bob)))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/bookings/{id}", id).header("Authorization", bearer(alice)))
                .andExpect(status().isNoContent());
        mvc.perform(delete("/bookings/{id}", id).header("Authorization", bearer(alice)))
                .andExpect(status().isNoContent());

        hold(bob, "A1", "A2").andExpect(status().isCreated());
        mvc.perform(get("/bookings/{id}", id).header("Authorization", bearer(alice)))
                .andExpect(jsonPath("$.status").value("CANCELLED"));
    }

    @Test
    void holdingAgainReplacesTheUsersEarlierHold() throws Exception {
        long first = bookingId(hold(alice, "A1", "A2"));
        hold(alice, "A3", "A4").andExpect(status().isCreated());

        assertThat(jdbc.queryForObject("SELECT status FROM bookings WHERE id = ?", String.class, first))
                .isEqualTo("CANCELLED");
        hold(bob, "A1", "A2").andExpect(status().isCreated());
    }

    @Test
    void paidBookingsCannotBeCancelled() throws Exception {
        long id = bookingId(hold(alice, "A1", "A2"));
        jdbc.update("UPDATE bookings SET status = 'PAID' WHERE id = ?", id);

        mvc.perform(delete("/bookings/{id}", id).header("Authorization", bearer(alice)))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("BOOKING_NOT_HOLDING"));
    }

    @Test
    void serverChecksTheSeatRulesAgain() throws Exception {
        expectError(hold(alice, "A1", "A3"), 422, "ORPHAN_SEAT");
        expectError(hold(alice, "B1"), 422, "COUPLE_SEAT_SPLIT");
        expectError(hold(alice), 400, "VALIDATION_FAILED");

        long otherRoomSeat = jdbc.queryForObject("SELECT id FROM seats WHERE auditorium_id <> ? LIMIT 1",
                Long.class, auditorium);
        expectError(holdIds(alice, showtime, List.of(otherRoomSeat)), 400, "VALIDATION_FAILED");

        long big = jdbc.queryForObject(
                "INSERT INTO auditoriums (cinema_id, name, row_count, col_count) "
                        + "SELECT cinema_id, 'P2', 1, 9 FROM auditoriums WHERE id = ? RETURNING id",
                Long.class, auditorium);
        List<Long> nine = new ArrayList<>();
        for (int col = 1; col <= 9; col++) {
            nine.add(jdbc.queryForObject("""
                    INSERT INTO seats (auditorium_id, row_label, col_number, seat_type_id)
                    SELECT ?, 'A', ?, id FROM seat_types WHERE code = 'STANDARD' RETURNING id
                    """, Long.class, big, col));
        }
        long bigShowtime = jdbc.queryForObject("""
                INSERT INTO showtimes (movie_id, auditorium_id, start_at, end_at, format, subtitle, base_price)
                VALUES (?, ?, ?, ?, '2D', 'SUB', ?) RETURNING id
                """, Long.class, movie, big, now.plusHours(3), now.plusHours(5), BASE_PRICE);
        expectError(holdIds(alice, bigShowtime, nine), 422, "SEAT_LIMIT_EXCEEDED");
    }

    @Test
    void salesCloseFifteenMinutesBeforeTheShow() throws Exception {
        long soon = showtime(now.plusMinutes(14));
        expectError(holdIds(alice, soon, List.of(seat.get("A1"), seat.get("A2"))), 409, "SHOWTIME_CLOSED");
        expectError(holdIds(alice, 999_999_999L, List.of(seat.get("A1"))), 404, "NOT_FOUND");
    }

    private String tryHold(long userId, long st) {
        try {
            holds.hold(userId, new HoldRequest(st, List.of(seat.get("A1"), seat.get("A2"))));
            return "OK";
        } catch (ApiException e) {
            return e.code().name();
        }
    }

    private long user(String name) {
        return jdbc.queryForObject("""
                INSERT INTO users (email, password_hash, full_name) VALUES (?, 'x', ?) RETURNING id
                """, Long.class, name + "-" + tag + "@test.dev", name);
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

    private int surcharge(String type) {
        return jdbc.queryForObject("SELECT surcharge FROM seat_types WHERE code = ?", Integer.class, type);
    }

    private ResultActions hold(long userId, String... labels) throws Exception {
        return holdIds(userId, showtime, Stream.of(labels).map(seat::get).toList());
    }

    private ResultActions holdIds(long userId, long st, List<Long> seatIds) throws Exception {
        return mvc.perform(post("/bookings").header("Authorization", bearer(userId))
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("showtimeId", st, "seatIds", seatIds))));
    }

    private long bookingId(ResultActions result) throws Exception {
        return json.readTree(result.andExpect(status().isCreated()).andReturn().getResponse().getContentAsString())
                .get("id").asLong();
    }

    private static void expectError(ResultActions result, int status, String code) throws Exception {
        result.andExpect(status().is(status)).andExpect(jsonPath("$.code").value(code));
    }

    private String bearer(long userId) {
        return "Bearer " + jwt.issueAccessToken(userId, Role.CUSTOMER);
    }
}
