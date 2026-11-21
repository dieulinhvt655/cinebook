package com.cinebook.catalog.dto;

import java.time.LocalDate;
import java.util.List;

/** S06. {@code trailerUrl} is a YouTube link the app opens externally. */
public record MovieDetail(long id, String title, String description, String posterUrl, String bannerUrl,
        String ageRating, int durationMin, LocalDate releaseDate, LocalDate endDate, String language,
        String trailerUrl, List<String> genres) {
}
