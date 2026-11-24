package com.cinebook.booking.dto;

import java.time.Instant;
import java.util.List;

/**
 * A booking as its owner sees it. Prices were fixed when the seats were held (seats) or the combos
 * were picked (combos). {@code status} is HOLDING, PAID, EXPIRED or CANCELLED; a hold past
 * {@code expiresAt} reads as EXPIRED even before the expiry job has run. The app counts down
 * {@code expiresAt - serverTime} so a wrong phone clock does not matter.
 */
public record BookingView(long id, String bookingCode, long showtimeId, String status, Show show,
        List<BookedSeat> seats, List<BookedCombo> combos, int seatTotal, int comboTotal, int totalAmount,
        Instant expiresAt, Instant paidAt, Instant serverTime) {

    /** What S10 and the ticket show about the showtime. {@code posterUrl} may be relative. */
    public record Show(long movieId, String movieTitle, String ageRating, String posterUrl, String cinemaName,
            String auditoriumName, Instant startAt, String format, String subtitle) {
    }

    /** {@code label} is row + column, e.g. "F7". */
    public record BookedSeat(long seatId, String label, String type, int price) {
    }

    public record BookedCombo(long comboId, String name, int quantity, int unitPrice) {
    }
}
