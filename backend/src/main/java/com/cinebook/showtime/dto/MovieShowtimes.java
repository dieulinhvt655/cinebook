package com.cinebook.showtime.dto;

import java.time.LocalDate;
import java.util.List;

/**
 * S07: showtimes of one movie on one Vietnam date, grouped by cinema. When that day has none,
 * {@code nextAvailableDate} suggests the closest later day that has (null if there is none).
 */
public record MovieShowtimes(long movieId, LocalDate date, List<CinemaShowtimes> cinemas,
        LocalDate nextAvailableDate) {
}
