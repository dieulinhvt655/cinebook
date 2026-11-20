package com.cinebook.booking;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Releases seat holds past {@code expires_at}: booking HOLDING -> EXPIRED and its booking_seats
 * become inactive, which frees the partial unique index (showtime_id, seat_id) WHERE is_active.
 * Seat-map reads also ignore expired holds, so correctness never depends on this job.
 */
@Service
public class HoldExpiryService {

    private final JdbcTemplate jdbc;

    public HoldExpiryService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** @return number of bookings expired */
    @Transactional
    public int expireOverdueHolds() {
        Integer expired = jdbc.queryForObject("""
                WITH expired AS (
                    UPDATE bookings SET status = 'EXPIRED', updated_at = now()
                     WHERE status = 'HOLDING' AND expires_at <= now()
                    RETURNING id
                ), released AS (
                    UPDATE booking_seats SET is_active = false
                     WHERE is_active AND booking_id IN (SELECT id FROM expired)
                )
                SELECT count(*) FROM expired
                """, Integer.class);
        return expired == null ? 0 : expired;
    }
}
