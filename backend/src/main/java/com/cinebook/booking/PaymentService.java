package com.cinebook.booking;

import com.cinebook.booking.dto.PaymentRequest;
import com.cinebook.booking.dto.PaymentView;
import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * F6 mock payment, shaped like a real gateway: each attempt is a {@code payments} row keyed by the
 * client's Idempotency-Key. SUCCESS marks the booking PAID and issues one ticket per seat; FAILED
 * leaves the hold untouched so the user can retry until it expires.
 *
 * <p>Double taps and network retries send the same key and get the first attempt back, so one key
 * never charges twice. The booking row is locked first, which also orders a payment against the
 * expiry job: whichever commits first wins, and a payment never lands on an expired hold.
 */
@Service
public class PaymentService {

    static final int MAX_KEY_LENGTH = 100;

    private final JdbcClient jdbc;
    private final BookingLocks locks;
    private final BookingQueryService bookings;
    private final TicketCodes tickets;

    public PaymentService(JdbcClient jdbc, BookingLocks locks, BookingQueryService bookings, TicketCodes tickets) {
        this.jdbc = jdbc;
        this.locks = locks;
        this.bookings = bookings;
        this.tickets = tickets;
    }

    @Transactional
    public PaymentView pay(long userId, long bookingId, String idempotencyKey, PaymentRequest.Result result) {
        if (idempotencyKey == null || idempotencyKey.isBlank() || idempotencyKey.length() > MAX_KEY_LENGTH) {
            throw new ApiException(ErrorCode.IDEMPOTENCY_KEY_REQUIRED,
                    "Thiếu hoặc sai header Idempotency-Key (tối đa " + MAX_KEY_LENGTH + " ký tự)");
        }
        // Ownership first: someone else's booking is 404 whatever the key.
        var booking = locks.lock(userId, bookingId);
        var earlier = find(idempotencyKey);
        if (earlier != null) {
            if (earlier.bookingId() != bookingId) {
                throw new ApiException(ErrorCode.VALIDATION_FAILED, "Idempotency-Key đã được dùng cho đơn khác");
            }
            return view(userId, earlier);
        }
        locks.requireHolding(booking);

        long paymentId;
        try {
            paymentId = jdbc.sql("""
                    INSERT INTO payments (booking_id, idempotency_key, method, amount, status, provider_ref)
                    VALUES (:bookingId, :key, 'MOCK', :amount, :status, :ref)
                    RETURNING id
                    """)
                    .param("bookingId", bookingId).param("key", idempotencyKey)
                    .param("amount", booking.totalAmount()).param("status", result.name())
                    .param("ref", "MOCK-" + UUID.randomUUID())
                    .query(Long.class).single();
        } catch (DuplicateKeyException e) {
            // Same key raced in for another booking (this booking's requests are serialised by the lock).
            throw new ApiException(ErrorCode.VALIDATION_FAILED, "Idempotency-Key đã được dùng cho đơn khác");
        }
        if (result == PaymentRequest.Result.SUCCESS) {
            jdbc.sql("UPDATE bookings SET status = 'PAID', paid_at = now(), updated_at = now() WHERE id = :id")
                    .param("id", bookingId).update();
            issueTickets(bookingId);
        }
        return view(userId, find(idempotencyKey));
    }

    private void issueTickets(long bookingId) {
        List<Long> seats = jdbc.sql("SELECT id FROM booking_seats WHERE booking_id = :id AND is_active ORDER BY id")
                .param("id", bookingId).query(Long.class).list();
        for (long seatRow : seats) {
            // Retry the (very unlikely) clash of two random codes.
            for (int attempt = 1; ; attempt++) {
                String code = tickets.next();
                int inserted = jdbc.sql("""
                        INSERT INTO tickets (booking_id, booking_seat_id, ticket_code, qr_payload)
                        VALUES (:bookingId, :seatRow, :code, :qr)
                        ON CONFLICT (ticket_code) DO NOTHING
                        """)
                        .param("bookingId", bookingId).param("seatRow", seatRow).param("code", code)
                        .param("qr", tickets.qrPayload(code)).update();
                if (inserted == 1) {
                    break;
                }
                if (attempt == 3) {
                    throw new IllegalStateException("Could not generate a unique ticket code");
                }
            }
        }
    }

    private Attempt find(String key) {
        return jdbc.sql("""
                SELECT id, booking_id, method, amount, status, created_at FROM payments WHERE idempotency_key = :key
                """)
                .param("key", key)
                .query((rs, n) -> new Attempt(rs.getLong("id"), rs.getLong("booking_id"), rs.getString("method"),
                        rs.getInt("amount"), rs.getString("status"),
                        rs.getObject("created_at", OffsetDateTime.class)))
                .optional().orElse(null);
    }

    private PaymentView view(long userId, Attempt a) {
        return new PaymentView(a.id(), a.bookingId(), a.method(), a.amount(), a.status(), a.createdAt().toInstant(),
                bookings.view(userId, a.bookingId()));
    }

    private record Attempt(long id, long bookingId, String method, int amount, String status,
            OffsetDateTime createdAt) {
    }
}
