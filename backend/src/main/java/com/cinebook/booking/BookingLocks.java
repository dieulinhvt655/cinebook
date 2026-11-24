package com.cinebook.booking;

import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import java.time.Clock;
import java.time.OffsetDateTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

/**
 * Locks the user's booking row for a change (combos, payment). The lock orders a payment against the
 * expiry job and against a second payment request for the same booking.
 */
@Component
class BookingLocks {

    private final JdbcClient jdbc;
    private final Clock clock;

    BookingLocks(JdbcClient jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    /** The booking, locked until the transaction ends; NOT_FOUND if it is not the user's. */
    Locked lock(long userId, long bookingId) {
        return jdbc.sql("""
                SELECT status, seat_total, combo_total, total_amount, expires_at
                  FROM bookings WHERE id = :id AND user_id = :userId
                   FOR UPDATE
                """)
                .param("id", bookingId).param("userId", userId)
                .query((rs, n) -> new Locked(bookingId, rs.getString("status"), rs.getInt("seat_total"),
                        rs.getInt("combo_total"), rs.getInt("total_amount"),
                        rs.getObject("expires_at", OffsetDateTime.class)))
                .optional()
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "Không tìm thấy đơn đặt vé"));
    }

    /** As {@link #lock} and the hold must still be live: 409 if paid or cancelled, 410 if expired. */
    Locked lockHolding(long userId, long bookingId) {
        return requireHolding(lock(userId, bookingId));
    }

    /** 409 if paid or cancelled, 410 if the hold ran out (even before the expiry job ran). */
    Locked requireHolding(Locked b) {
        switch (b.status()) {
            case "PAID" -> throw new ApiException(ErrorCode.BOOKING_NOT_HOLDING, "Đơn đã được thanh toán");
            case "CANCELLED" -> throw new ApiException(ErrorCode.BOOKING_NOT_HOLDING, "Đơn đã bị huỷ");
            case "HOLDING" -> {
                if (b.expiresAt().isAfter(OffsetDateTime.now(clock))) {
                    return b;
                }
            }
            default -> {
            }
        }
        throw new ApiException(ErrorCode.HOLD_EXPIRED, "Hết thời gian giữ ghế, vui lòng chọn lại ghế");
    }

    record Locked(long id, String status, int seatTotal, int comboTotal, int totalAmount, OffsetDateTime expiresAt) {
    }
}
