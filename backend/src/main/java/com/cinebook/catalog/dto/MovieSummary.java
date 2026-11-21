package com.cinebook.catalog.dto;

import java.time.LocalDate;
import java.util.List;

/** One poster in the home grid or the search results. Image URLs are null until uploaded. */
public record MovieSummary(long id, String title, String posterUrl, String bannerUrl, String ageRating,
        int durationMin, LocalDate releaseDate, List<String> genres) {
}
