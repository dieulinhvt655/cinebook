package com.cinebook.booking;

import com.cinebook.booking.dto.BookingView;
import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Read side of a booking, for its owner only. */
@Service
@Transactional(readOnly = true)
public class BookingQueryService {

    private final JdbcClient jdbc;
    private final Clock clock;

    public BookingQueryService(JdbcClient jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    /** Another user's booking is reported as missing, so ids cannot be probed. */
    public BookingView view(long userId, long bookingId) {
        Instant now = clock.instant();
        Header h = jdbc.sql("""
                SELECT id, booking_code, showtime_id, status, seat_total, combo_total, total_amount, expires_at
                  FROM bookings WHERE id = :id AND user_id = :userId
                """)
                .param("id", bookingId).param("userId", userId)
                .query((rs, n) -> new Header(rs.getLong("id"), rs.getString("booking_code"), rs.getLong("showtime_id"),
                        rs.getString("status"), rs.getInt("seat_total"), rs.getInt("combo_total"),
                        rs.getInt("total_amount"), rs.getObject("expires_at", OffsetDateTime.class).toInstant()))
                .optional()
                .orElseThrow(BookingQueryService::notFound);
        // Seats of a cancelled or expired hold are inactive but still part of its history.
        var seats = jdbc.sql("""
                SELECT bs.seat_id, st.row_label || st.col_number AS label, bs.seat_type_code, bs.price
                  FROM booking_seats bs JOIN seats st ON st.id = bs.seat_id
                 WHERE bs.booking_id = :id
                 ORDER BY length(st.row_label), st.row_label, st.col_number
                """)
                .param("id", bookingId)
                .query((rs, n) -> new BookingView.BookedSeat(rs.getLong("seat_id"), rs.getString("label"),
                        rs.getString("seat_type_code"), rs.getInt("price")))
                .list();
        String status = "HOLDING".equals(h.status()) && !h.expiresAt().isAfter(now) ? "EXPIRED" : h.status();
        return new BookingView(h.id(), h.code(), h.showtimeId(), status, seats, h.seatTotal(), h.comboTotal(),
                h.totalAmount(), h.expiresAt(), now);
    }

    /** Stored status of the user's booking; NOT_FOUND if it is not theirs. */
    String ownedStatus(long userId, long bookingId) {
        return jdbc.sql("SELECT status FROM bookings WHERE id = :id AND user_id = :userId")
                .param("id", bookingId).param("userId", userId)
                .query(String.class).optional()
                .orElseThrow(BookingQueryService::notFound);
    }

    private static ApiException notFound() {
        return new ApiException(ErrorCode.NOT_FOUND, "Không tìm thấy đơn đặt vé");
    }

    private record Header(long id, String code, long showtimeId, String status, int seatTotal, int comboTotal,
            int totalAmount, Instant expiresAt) {
    }
}
