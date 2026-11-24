package com.cinebook.ticket;

import com.cinebook.booking.dto.BookingView;
import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import com.cinebook.ticket.dto.TicketDetail;
import com.cinebook.ticket.dto.TicketSummary;
import java.sql.Array;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.List;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * F7: the user's own paid bookings. Ownership is part of every query, so another user's ticket is
 * reported as missing (404), the same as bookings.
 */
@Service
@Transactional(readOnly = true)
public class TicketQueryService {

    private static final String FROM = """
              FROM bookings b
              JOIN showtimes s ON s.id = b.showtime_id
              JOIN movies m ON m.id = s.movie_id
              JOIN auditoriums a ON a.id = s.auditorium_id
              JOIN cinemas c ON c.id = a.cinema_id
              LEFT JOIN media_assets p ON p.id = m.poster_id
            """;
    private static final String SHOW_COLUMNS = """
            m.id AS movie_id, m.title, m.age_rating, p.url AS poster_url, c.name AS cinema_name,
            a.name AS auditorium_name, s.start_at, s.end_at, s.format, s.subtitle
            """;

    private final JdbcClient jdbc;
    private final Clock clock;
    private final TicketService tickets;

    public TicketQueryService(JdbcClient jdbc, Clock clock, TicketService tickets) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.tickets = tickets;
    }

    /** Newest purchase first. A ticket is upcoming until its showtime has ended. */
    public List<TicketSummary> mine(long userId, TicketScope scope) {
        String when = scope == TicketScope.UPCOMING ? "s.end_at > :now" : "s.end_at <= :now";
        return jdbc.sql("SELECT b.id, b.booking_code, b.paid_at, " + SHOW_COLUMNS + """
                       , ARRAY(SELECT st.row_label || st.col_number
                                 FROM booking_seats bs JOIN seats st ON st.id = bs.seat_id
                                WHERE bs.booking_id = b.id AND bs.is_active
                                ORDER BY length(st.row_label), st.row_label, st.col_number) AS seats
                """ + FROM + " WHERE b.user_id = :userId AND b.status = 'PAID' AND " + when
                + " ORDER BY b.paid_at DESC, b.id DESC")
                .param("userId", userId).param("now", OffsetDateTime.now(clock))
                .query((rs, n) -> new TicketSummary(rs.getLong("id"), rs.getString("booking_code"), show(rs),
                        labels(rs.getArray("seats")), rs.getObject("paid_at", OffsetDateTime.class).toInstant()))
                .list();
    }

    public TicketDetail detail(long userId, long bookingId) {
        Instant now = clock.instant();
        record Head(String code, BookingView.Show show, Instant endAt, int seatTotal, int comboTotal, int total,
                Instant paidAt) {
        }
        Head h = jdbc.sql("SELECT b.booking_code, b.seat_total, b.combo_total, b.total_amount, b.paid_at, "
                + SHOW_COLUMNS + FROM + " WHERE b.id = :id AND b.user_id = :userId AND b.status = 'PAID'")
                .param("id", bookingId).param("userId", userId)
                .query((rs, n) -> new Head(rs.getString("booking_code"), show(rs),
                        rs.getObject("end_at", OffsetDateTime.class).toInstant(), rs.getInt("seat_total"),
                        rs.getInt("combo_total"), rs.getInt("total_amount"),
                        rs.getObject("paid_at", OffsetDateTime.class).toInstant()))
                .optional()
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "Không tìm thấy vé"));
        var seats = jdbc.sql("""
                SELECT st.row_label || st.col_number AS label, bs.seat_type_code, bs.price, t.ticket_code, t.status
                  FROM booking_seats bs
                  JOIN seats st ON st.id = bs.seat_id
                  JOIN tickets t ON t.booking_seat_id = bs.id
                 WHERE bs.booking_id = :id AND bs.is_active
                 ORDER BY length(st.row_label), st.row_label, st.col_number
                """)
                .param("id", bookingId)
                .query((rs, n) -> new TicketDetail.SeatTicket(rs.getString("label"), rs.getString("seat_type_code"),
                        rs.getInt("price"), rs.getString("ticket_code"), rs.getString("status")))
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
        return new TicketDetail(bookingId, h.code(), tickets.qrPayloadForBooking(h.code()), h.endAt().isAfter(now),
                h.show(), seats, combos, h.seatTotal(), h.comboTotal(), h.total(), h.paidAt());
    }

    private static BookingView.Show show(ResultSet rs) throws SQLException {
        return new BookingView.Show(rs.getLong("movie_id"), rs.getString("title"), rs.getString("age_rating"),
                rs.getString("poster_url"), rs.getString("cinema_name"), rs.getString("auditorium_name"),
                rs.getObject("start_at", OffsetDateTime.class).toInstant(), rs.getString("format"),
                rs.getString("subtitle"));
    }

    private static List<String> labels(Array array) throws SQLException {
        return Arrays.stream((Object[]) array.getArray()).map(Object::toString).toList();
    }
}
