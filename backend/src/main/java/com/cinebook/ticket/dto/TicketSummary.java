package com.cinebook.ticket.dto;

import com.cinebook.booking.dto.BookingView;
import java.time.Instant;
import java.util.List;

/** A card on S12: one paid booking. {@code id} is the booking id, used by {@code GET /tickets/{id}}. */
public record TicketSummary(long id, String bookingCode, BookingView.Show show, List<String> seats,
        Instant paidAt) {
}
