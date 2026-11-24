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
                SELECT b.id, b.booking_code, b.showtime_id, b.status, b.seat_total, b.combo_total, b.total_amount,
                       b.expires_at, b.paid_at,
                       m.id AS movie_id, m.title, m.age_rating, p.url AS poster_url,
                       c.name AS cinema_name, a.name AS auditorium_name, s.start_at, s.format, s.subtitle
                  FROM bookings b
                  JOIN showtimes s ON s.id = b.showtime_id
                  JOIN movies m ON m.id = s.movie_id
                  JOIN auditoriums a ON a.id = s.auditorium_id
                  JOIN cinemas c ON c.id = a.cinema_id
                  LEFT JOIN media_assets p ON p.id = m.poster_id
                 WHERE b.id = :id AND b.user_id = :userId
                """)
                .param("id", bookingId).param("userId", userId)
                .query((rs, n) -> {
                    OffsetDateTime paidAt = rs.getObject("paid_at", OffsetDateTime.class);
                    return new Header(rs.getLong("id"), rs.getString("booking_code"), rs.getLong("showtime_id"),
                            rs.getString("status"), rs.getInt("seat_total"), rs.getInt("combo_total"),
                            rs.getInt("total_amount"), rs.getObject("expires_at", OffsetDateTime.class).toInstant(),
                            paidAt == null ? null : paidAt.toInstant(),
                            new BookingView.Show(rs.getLong("movie_id"), rs.getString("title"),
                                    rs.getString("age_rating"), rs.getString("poster_url"),
                                    rs.getString("cinema_name"), rs.getString("auditorium_name"),
                                    rs.getObject("start_at", OffsetDateTime.class).toInstant(),
                                    rs.getString("format"), rs.getString("subtitle")));
                })
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
        var combos = jdbc.sql("""
                SELECT bc.combo_id, c.name, bc.quantity, bc.unit_price
                  FROM booking_combos bc JOIN combos c ON c.id = bc.combo_id
                 WHERE bc.booking_id = :id
                 ORDER BY bc.unit_price, bc.combo_id
                """)
                .param("id", bookingId)
                .query((rs, n) -> new BookingView.BookedCombo(rs.getLong("combo_id"), rs.getString("name"),
                        rs.getInt("quantity"), rs.getInt("unit_price")))
                .list();
        String status = "HOLDING".equals(h.status()) && !h.expiresAt().isAfter(now) ? "EXPIRED" : h.status();
        return new BookingView(h.id(), h.code(), h.showtimeId(), status, h.show(), seats, combos, h.seatTotal(),
                h.comboTotal(), h.totalAmount(), h.expiresAt(), h.paidAt(), now);
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
            int totalAmount, Instant expiresAt, Instant paidAt, BookingView.Show show) {
    }
}
