package com.cinebook.booking.dto;

import java.time.Instant;
import java.util.List;

/**
 * One row of the transaction history on S14. {@code status} is HOLDING, PAID, EXPIRED or CANCELLED;
 * {@code paidAt} is null unless PAID. A PAID {@code id} opens {@code GET /tickets/{id}}.
 */
public record BookingHistoryItem(long id, String bookingCode, String status, BookingView.Show show,
        List<String> seats, int totalAmount, Instant createdAt, Instant paidAt) {
}
