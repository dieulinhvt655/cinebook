package com.cinebook.showtime.dto;

import com.cinebook.catalog.dto.CinemaInfo;
import java.time.LocalDate;
import java.util.List;

/**
 * "Rạp" tab, one cinema and one Vietnam day: the movies it shows and their showtimes (S07 the
 * other way round). {@code nextAvailableDate} is only set when the day has no showtime.
 */
public record CinemaSchedule(CinemaInfo cinema, LocalDate date, List<MovieSlots> movies, LocalDate nextAvailableDate) {

    /** {@code posterUrl} may be relative to the API base, like {@code MovieSummary.posterUrl}. */
    public record MovieSlots(long movieId, String title, String posterUrl, String ageRating, int durationMin,
            List<ShowtimeSlot> showtimes) {
    }
}
