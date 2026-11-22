package com.cinebook.showtime;

import com.cinebook.booking.BookingProperties;
import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import com.cinebook.showtime.dto.SeatMap;
import com.cinebook.showtime.dto.SeatStatus;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** S08 (F4): seat layout of a showtime's room with each seat's live status and price. */
@Service
@Transactional(readOnly = true)
public class SeatMapQueryService {

    private final JdbcClient jdbc;
    private final Clock clock;
    private final BookingProperties booking;

    public SeatMapQueryService(JdbcClient jdbc, Clock clock, BookingProperties booking) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.booking = booking;
    }

    /**
     * 404 when the showtime does not exist, is cancelled, or its movie or cinema is hidden. A
     * showtime past the sales cutoff (or already started) is still returned, with
     * {@code bookable=false}, so the app can explain why instead of showing an error.
     */
    public SeatMap forShowtime(long showtimeId) {
        OffsetDateTime now = OffsetDateTime.now(clock).withOffsetSameInstant(ZoneOffset.UTC);
        Header h = jdbc.sql("""
                SELECT s.id, s.start_at, s.end_at, s.format, s.subtitle, s.base_price,
                       m.id AS movie_id, m.title, m.age_rating, m.duration_min, p.url AS poster_url,
                       c.id AS cinema_id, c.name AS cinema_name,
                       a.id AS auditorium_id, a.name AS auditorium_name, a.row_count, a.col_count
                  FROM showtimes s
                  JOIN movies m ON m.id = s.movie_id
                  JOIN auditoriums a ON a.id = s.auditorium_id
                  JOIN cinemas c ON c.id = a.cinema_id
                  LEFT JOIN media_assets p ON p.id = m.poster_id
                 WHERE s.id = :id AND s.status = 'OPEN' AND m.is_active AND c.is_active
                """)
                .param("id", showtimeId)
                .query((rs, n) -> new Header(rs.getLong("id"),
                        rs.getObject("start_at", OffsetDateTime.class).toInstant(),
                        rs.getObject("end_at", OffsetDateTime.class).toInstant(), rs.getString("format"),
                        rs.getString("subtitle"), rs.getInt("base_price"),
                        new SeatMap.Movie(rs.getLong("movie_id"), rs.getString("title"), rs.getString("age_rating"),
                                rs.getInt("duration_min"), rs.getString("poster_url")),
                        new SeatMap.Venue(rs.getLong("cinema_id"), rs.getString("cinema_name"),
                                rs.getLong("auditorium_id"), rs.getString("auditorium_name"), rs.getInt("row_count"),
                                rs.getInt("col_count"))))
                .optional()
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "Không tìm thấy suất chiếu"));

        // Ordered A..Z then AA..: rows with longer labels come after.
        Map<String, List<SeatMap.Seat>> byRow = new LinkedHashMap<>();
        Map<String, SeatMap.SeatType> types = new TreeMap<>();
        int[] available = {0};
        jdbc.sql("""
                SELECT st.id, st.row_label, st.col_number, st.pair_seat_id,
                       t.code, t.name AS type_name, t.surcharge, t.seats_per_unit,
                       CASE b.status WHEN 'PAID' THEN 'SOLD' WHEN 'HOLDING' THEN 'HELD' ELSE 'AVAILABLE' END AS status
                  FROM showtimes s
                  JOIN seats st ON st.auditorium_id = s.auditorium_id
                  JOIN seat_types t ON t.id = st.seat_type_id
                  -- at most one active row per (showtime, seat), enforced by uq_booking_seats_active
                  LEFT JOIN (booking_seats bs JOIN bookings b ON b.id = bs.booking_id AND\s""" + SeatAvailability.LIVE_BOOKING + """
                            ) ON bs.showtime_id = s.id AND bs.seat_id = st.id AND bs.is_active
                 WHERE s.id = :id AND st.is_active
                 ORDER BY length(st.row_label), st.row_label, st.col_number
                """)
                .param("id", showtimeId).param("now", now)
                .query(rs -> {
                    int price = h.basePrice() + rs.getInt("surcharge");
                    String code = rs.getString("code");
                    types.putIfAbsent(code, new SeatMap.SeatType(code, rs.getString("type_name"),
                            rs.getInt("surcharge"), rs.getInt("seats_per_unit"), price));
                    SeatStatus status = SeatStatus.valueOf(rs.getString("status"));
                    if (status == SeatStatus.AVAILABLE) {
                        available[0]++;
                    }
                    long pair = rs.getLong("pair_seat_id");
                    String row = rs.getString("row_label");
                    byRow.computeIfAbsent(row, r -> new ArrayList<>()).add(new SeatMap.Seat(rs.getLong("id"), row,
                            rs.getInt("col_number"), code, price, status, rs.wasNull() ? null : pair));
                });

        List<SeatMap.SeatRow> rows = byRow.entrySet().stream()
                .map(e -> new SeatMap.SeatRow(e.getKey(), List.copyOf(e.getValue()))).toList();
        List<SeatMap.SeatType> seatTypes = types.values().stream()
                .sorted((a, b) -> Integer.compare(a.surcharge(), b.surcharge())).toList();
        Instant salesCloseAfter = now.toInstant().plus(booking.salesCutoff());
        return new SeatMap(h.id(), h.startAt(), h.endAt(), h.format(), h.subtitle(), h.basePrice(),
                h.startAt().isAfter(salesCloseAfter), h.movie(), h.venue(), seatTypes, rows, available[0],
                booking.maxSeats(), now.toInstant());
    }

    private record Header(long id, Instant startAt, Instant endAt, String format, String subtitle, int basePrice,
            SeatMap.Movie movie, SeatMap.Venue venue) {
    }
}
