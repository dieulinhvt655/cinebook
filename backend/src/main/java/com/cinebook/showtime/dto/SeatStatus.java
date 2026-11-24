package com.cinebook.showtime.dto;

/**
 * Derived, never stored: SOLD = an active booking_seats row of a PAID booking, HELD = an active row
 * of a HOLDING booking whose {@code expires_at} is still in the future. "Selected" is client-side.
 */
public enum SeatStatus {
    AVAILABLE, HELD, SOLD
}
