package com.cinebook.ticket.dto;

import com.cinebook.booking.dto.BookingView;
import java.time.Instant;
import java.util.List;

/**
 * S13: the ticket stub. {@code qrPayload} is the signed booking code shown as one QR; each seat also
 * has its own ticket code. {@code upcoming} is false once the showtime has ended.
 */
public record TicketDetail(long id, String bookingCode, String qrPayload, boolean upcoming, BookingView.Show show,
        List<SeatTicket> seats, List<BookingView.BookedCombo> combos, int seatTotal, int comboTotal,
        int totalAmount, Instant paidAt) {

    /** {@code status} is VALID, USED or VOID. */
    public record SeatTicket(String label, String type, int price, String ticketCode, String status) {
    }
}
