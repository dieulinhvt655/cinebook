package com.cinebook.booking;

import com.cinebook.booking.SeatRules.RoomSeat;
import com.cinebook.booking.dto.BookingView;
import com.cinebook.booking.dto.HoldRequest;
import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * F5: holds seats for {@link BookingProperties#holdTtl()} (10 min), releases them on cancel.
 *
 * <p>Two people can never hold the same seat: each held seat is an active {@code booking_seats}
 * row and the partial unique index {@code uq_booking_seats_active (showtime_id, seat_id) WHERE
 * is_active} rejects the second insert, even for requests in the same millisecond. The checks
 * before the insert only give clearer messages; the index is the guarantee.
 */
@Service
public class SeatHoldService {

    static final String SEAT_TAKEN_MESSAGE = "Ghế vừa được người khác chọn, vui lòng chọn ghế khác";
    private static final String UNIQUE_SEAT_INDEX = "uq_booking_seats_active";
    private static final String UNIQUE_CODE = "bookings_booking_code_key";

    private final JdbcClient jdbc;
    private final Clock clock;
    private final BookingProperties props;
    private final BookingQueryService bookings;

    public SeatHoldService(JdbcClient jdbc, Clock clock, BookingProperties props, BookingQueryService bookings) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.props = props;
        this.bookings = bookings;
    }

    @Transactional
    public BookingView hold(long userId, HoldRequest request) {
        Set<Long> selected = new LinkedHashSet<>(request.seatIds());
        if (selected.size() > props.maxSeats()) {
            throw new ApiException(ErrorCode.SEAT_LIMIT_EXCEEDED,
                    "Tối đa " + props.maxSeats() + " ghế mỗi lần đặt");
        }
        OffsetDateTime now = OffsetDateTime.now(clock).withOffsetSameInstant(ZoneOffset.UTC);
        long showtimeId = request.showtimeId();
        Showtime showtime = jdbc.sql("""
                SELECT s.auditorium_id, s.base_price, s.start_at
                  FROM showtimes s
                  JOIN movies m ON m.id = s.movie_id
                  JOIN auditoriums a ON a.id = s.auditorium_id
                  JOIN cinemas c ON c.id = a.cinema_id
                 WHERE s.id = :id AND s.status = 'OPEN' AND m.is_active AND c.is_active
                """)
                .param("id", showtimeId)
                .query((rs, n) -> new Showtime(rs.getLong("auditorium_id"), rs.getInt("base_price"),
                        rs.getObject("start_at", OffsetDateTime.class)))
                .optional()
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "Không tìm thấy suất chiếu"));
        if (!showtime.startAt().isAfter(now.plus(props.salesCutoff()))) {
            throw new ApiException(ErrorCode.SHOWTIME_CLOSED,
                    "Suất chiếu đã đóng bán online (" + props.salesCutoff().toMinutes() + " phút trước giờ chiếu)");
        }

        releaseOverdueHolds(showtimeId, now);
        // Going back to the seat map and pressing "Tiếp tục" again replaces the user's earlier hold.
        cancelHolds("user_id = :userId AND showtime_id = :showtimeId",
                Map.of("userId", userId, "showtimeId", showtimeId));

        List<RoomSeat> room = roomSeats(showtimeId, showtime.auditoriumId(), now);
        Map<Long, RoomSeat> byId = room.stream().collect(Collectors.toMap(RoomSeat::id, Function.identity()));
        if (!byId.keySet().containsAll(selected)) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED, "Ghế không thuộc phòng chiếu của suất này");
        }
        // Same insert order for everyone, so two overlapping holds cannot deadlock on the index.
        List<RoomSeat> chosen = selected.stream().sorted().map(byId::get).toList();
        chosen.stream().filter(s -> !s.free()).findFirst().ifPresent(s -> {
            throw new ApiException(ErrorCode.SEAT_TAKEN, SEAT_TAKEN_MESSAGE);
        });
        SeatRules.splitCouple(room, selected).ifPresent(s -> {
            throw new ApiException(ErrorCode.COUPLE_SEAT_SPLIT, "Ghế đôi " + s.label() + " phải chọn cả cặp");
        });
        SeatRules.orphan(room, selected).ifPresent(s -> {
            throw new ApiException(ErrorCode.ORPHAN_SEAT,
                    "Không được để trống 1 ghế lẻ (" + s.label() + "), vui lòng chọn lại");
        });

        int seatTotal = chosen.stream().mapToInt(s -> showtime.basePrice() + s.surcharge()).sum();
        long bookingId = insertBooking(userId, showtimeId, seatTotal, now.plus(props.holdTtl()));
        try {
            for (RoomSeat s : chosen) {
                jdbc.sql("""
                        INSERT INTO booking_seats (booking_id, showtime_id, seat_id, seat_type_code, price)
                        VALUES (:bookingId, :showtimeId, :seatId, :type, :price)
                        """)
                        .param("bookingId", bookingId).param("showtimeId", showtimeId).param("seatId", s.id())
                        .param("type", s.type()).param("price", showtime.basePrice() + s.surcharge())
                        .update();
            }
        } catch (DuplicateKeyException e) {
            // Someone else's insert committed first; the transaction rolls back, including the booking.
            if (violates(e, UNIQUE_SEAT_INDEX)) {
                throw new ApiException(ErrorCode.SEAT_TAKEN, SEAT_TAKEN_MESSAGE);
            }
            throw e;
        }
        return bookings.view(userId, bookingId);
    }

    /**
     * Releases the seats of the user's own hold at once ("Huỷ giữ ghế?" or Back on S09). Cancelling
     * an expired or already cancelled booking is a no-op, so retries are safe.
     */
    @Transactional
    public void cancel(long userId, long bookingId) {
        String status = bookings.ownedStatus(userId, bookingId);
        if ("PAID".equals(status)) {
            throw new ApiException(ErrorCode.BOOKING_NOT_HOLDING, "Đơn đã thanh toán, không thể huỷ");
        }
        // Owner filter again in the UPDATE itself, not only in the check above.
        cancelHolds("id = :id AND user_id = :userId", Map.of("id", bookingId, "userId", userId));
    }

    private void releaseOverdueHolds(long showtimeId, OffsetDateTime now) {
        jdbc.sql("""
                WITH expired AS (
                    UPDATE bookings SET status = 'EXPIRED', updated_at = now()
                     WHERE showtime_id = :showtimeId AND status = 'HOLDING' AND expires_at <= :now
                    RETURNING id
                )
                UPDATE booking_seats SET is_active = false
                 WHERE is_active AND booking_id IN (SELECT id FROM expired)
                """)
                .param("showtimeId", showtimeId).param("now", now).update();
    }

    /** HOLDING bookings matching {@code where} become CANCELLED and free their seats. */
    private void cancelHolds(String where, Map<String, ?> params) {
        jdbc.sql("""
                WITH cancelled AS (
                    UPDATE bookings SET status = 'CANCELLED', updated_at = now()
                     WHERE status = 'HOLDING' AND\s""" + where + """
                    RETURNING id
                )
                UPDATE booking_seats SET is_active = false
                 WHERE is_active AND booking_id IN (SELECT id FROM cancelled)
                """)
                .params(params).update();
    }

    private List<RoomSeat> roomSeats(long showtimeId, long auditoriumId, OffsetDateTime now) {
        return jdbc.sql("""
                SELECT st.id, st.row_label, st.col_number, st.pair_seat_id, t.code, t.surcharge,
                       NOT EXISTS (SELECT 1 FROM booking_seats bs JOIN bookings b ON b.id = bs.booking_id
                                    WHERE bs.showtime_id = :showtimeId AND bs.seat_id = st.id AND bs.is_active
                                      AND (b.status = 'PAID' OR (b.status = 'HOLDING' AND b.expires_at > :now))
                                  ) AS free
                  FROM seats st
                  JOIN seat_types t ON t.id = st.seat_type_id
                 WHERE st.auditorium_id = :auditoriumId AND st.is_active
                """)
                .param("showtimeId", showtimeId).param("auditoriumId", auditoriumId).param("now", now)
                .query((rs, n) -> new RoomSeat(rs.getLong("id"), rs.getString("row_label"), rs.getInt("col_number"),
                        rs.getString("code"), rs.getInt("surcharge"), rs.getObject("pair_seat_id", Long.class),
                        rs.getBoolean("free")))
                .list();
    }

    /** Retries the (very unlikely) clash of two random booking codes. */
    private long insertBooking(long userId, long showtimeId, int seatTotal, OffsetDateTime expiresAt) {
        for (int attempt = 1; ; attempt++) {
            try {
                return jdbc.sql("""
                        INSERT INTO bookings (booking_code, user_id, showtime_id, status, seat_total, total_amount,
                                              expires_at)
                        VALUES (:code, :userId, :showtimeId, 'HOLDING', :total, :total, :expiresAt)
                        ON CONFLICT (booking_code) DO NOTHING
                        RETURNING id
                        """)
                        .param("code", BookingCodes.next()).param("userId", userId).param("showtimeId", showtimeId)
                        .param("total", seatTotal).param("expiresAt", expiresAt)
                        .query(Long.class).optional()
                        .orElseThrow(() -> new DuplicateKeyException(UNIQUE_CODE));
            } catch (DuplicateKeyException e) {
                if (attempt == 3 || !violates(e, UNIQUE_CODE)) {
                    throw e;
                }
            }
        }
    }

    private static boolean violates(DuplicateKeyException e, String constraint) {
        return e.getMessage() != null && e.getMessage().contains(constraint);
    }

    private record Showtime(long auditoriumId, int basePrice, OffsetDateTime startAt) {
    }
}
