package com.cinebook.booking.dto;

import java.time.Instant;

/**
 * One payment attempt. {@code status} SUCCESS means the booking is now PAID and its tickets exist;
 * FAILED leaves the hold as it was, so the user can try again until it expires. Sending the same
 * Idempotency-Key again returns this same attempt.
 */
public record PaymentView(long id, long bookingId, String method, int amount, String status, Instant createdAt,
        BookingView booking) {
}
