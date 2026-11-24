package com.cinebook.showtime.dto;

import java.time.Instant;

/**
 * One showtime button. {@code bookable} is false once online sales have closed
 * ({@code cinebook.booking.sales-cutoff} before the start); started showtimes are not listed.
 * {@code availableSeats} counts seats neither sold nor under a live hold.
 */
public record ShowtimeSlot(long id, Instant startAt, Instant endAt, String format, String subtitle,
        String auditorium, int basePrice, boolean bookable, int availableSeats) {
}
