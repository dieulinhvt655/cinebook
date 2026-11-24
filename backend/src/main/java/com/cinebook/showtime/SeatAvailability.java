package com.cinebook.showtime;

/**
 * The one definition of "this seat is taken for this showtime", shared by the seat map (S08) and
 * the free-seat counts on S07. A hold past {@code expires_at} no longer counts even before
 * {@code HoldExpiryJob} has released it, so reads never depend on that job.
 */
final class SeatAvailability {

    /** Booking {@code b} still owns its active seats. Needs a {@code :now} parameter. */
    static final String LIVE_BOOKING = "(b.status = 'PAID' OR (b.status = 'HOLDING' AND b.expires_at > :now))";

    /** Free seats of showtime {@code s}. */
    static final String FREE_COUNT = """
            (SELECT count(*) FROM seats st
              WHERE st.auditorium_id = s.auditorium_id AND st.is_active
                AND NOT EXISTS (SELECT 1 FROM booking_seats bs
                                  JOIN bookings b ON b.id = bs.booking_id
                                 WHERE bs.showtime_id = s.id AND bs.seat_id = st.id AND bs.is_active
                                   AND\s""" + LIVE_BOOKING + "))";

    private SeatAvailability() {
    }
}
