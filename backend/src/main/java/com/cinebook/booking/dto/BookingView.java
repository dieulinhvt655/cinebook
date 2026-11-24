package com.cinebook.booking.dto;

import java.time.Instant;
import java.util.List;

/**
 * A booking as its owner sees it. Prices were fixed when the seats were held. {@code status} is
 * HOLDING, PAID, EXPIRED or CANCELLED; a hold past {@code expiresAt} reads as EXPIRED even before
 * the expiry job has run. The app counts down {@code expiresAt - serverTime} so a wrong phone
 * clock does not matter.
 */
public record BookingView(long id, String bookingCode, long showtimeId, String status, List<BookedSeat> seats,
        int seatTotal, int comboTotal, int totalAmount, Instant expiresAt, Instant serverTime) {

    /** {@code label} is row + column, e.g. "F7". */
    public record BookedSeat(long seatId, String label, String type, int price) {
    }
}
