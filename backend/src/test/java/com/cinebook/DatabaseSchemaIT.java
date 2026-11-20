package com.cinebook;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.cinebook.booking.HoldExpiryService;
import com.cinebook.support.IntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

@IntegrationTest
@Transactional
class DatabaseSchemaIT {

    @Autowired
    JdbcTemplate jdbc;

    @Autowired
    HoldExpiryService holdExpiryService;

    @Test
    void seedLoadsDemoCatalogue() {
        assertThat(count("SELECT count(*) FROM cinemas")).isEqualTo(3);
        assertThat(count("SELECT count(*) FROM movies")).isEqualTo(12);
        assertThat(count("SELECT count(*) FROM seats")).isEqualTo(9 * 120);
        assertThat(count("SELECT count(*) FROM seats WHERE row_label = 'J' AND pair_seat_id IS NULL")).isZero();
        assertThat(count("SELECT count(*) FROM showtimes")).isGreaterThan(0);
    }

    @Test
    void searchIgnoresAccentsAndCase() {
        assertThat(jdbc.queryForList(
                "SELECT title FROM movies WHERE title_unaccent ILIKE '%' || lower(immutable_unaccent(?)) || '%'",
                String.class, "CHO DEM")).containsExactly("Chợ Đêm");
        assertThat(jdbc.queryForList(
                "SELECT title FROM movies WHERE title_unaccent ILIKE ?", String.class, "%avengers%"))
                .containsExactly("Avengers of the Abyss");
    }

    @Test
    void sameSeatCannotBeHeldTwiceButIsFreedWhenHoldExpires() {
        long showtimeId = count("SELECT min(id) FROM showtimes");
        long seatId = count("""
                SELECT min(s.id) FROM seats s JOIN showtimes st ON st.auditorium_id = s.auditorium_id
                 WHERE st.id = %d""".formatted(showtimeId));

        long first = hold(showtimeId, seatId, "CBTEST01", "now() + interval '10 minutes'");
        assertThatThrownBy(() -> hold(showtimeId, seatId, "CBTEST02", "now() + interval '10 minutes'"))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("uq_booking_seats_active");

        jdbc.update("UPDATE bookings SET expires_at = now() - interval '1 second' WHERE id = ?", first);
        assertThat(holdExpiryService.expireOverdueHolds()).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT status FROM bookings WHERE id = ?", String.class, first))
                .isEqualTo("EXPIRED");

        hold(showtimeId, seatId, "CBTEST03", "now() + interval '10 minutes'");
    }

    @Test
    void overlappingShowtimesInSameAuditoriumAreRejected() {
        assertThatThrownBy(() -> jdbc.update("""
                INSERT INTO showtimes (movie_id, auditorium_id, start_at, end_at, format, subtitle, base_price)
                SELECT movie_id, auditorium_id, start_at + interval '30 minutes', end_at, format, subtitle, base_price
                  FROM showtimes ORDER BY id LIMIT 1"""))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("showtimes_no_overlap");
    }

    private long hold(long showtimeId, long seatId, String code, String expiresAtSql) {
        long userId = count("SELECT id FROM users WHERE email = 'demo@cinebook.dev'");
        Long bookingId = jdbc.queryForObject("""
                INSERT INTO bookings (booking_code, user_id, showtime_id, status, seat_total, total_amount, expires_at)
                VALUES (?, ?, ?, 'HOLDING', 80000, 80000, %s) RETURNING id""".formatted(expiresAtSql),
                Long.class, code, userId, showtimeId);
        jdbc.update("""
                INSERT INTO booking_seats (booking_id, showtime_id, seat_id, seat_type_code, price)
                VALUES (?, ?, ?, 'STANDARD', 80000)""", bookingId, showtimeId, seatId);
        return bookingId;
    }

    private long count(String sql) {
        Long n = jdbc.queryForObject(sql, Long.class);
        return n == null ? 0 : n;
    }
}
