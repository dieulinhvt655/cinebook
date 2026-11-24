package com.cinebook.catalog.dto;

import java.time.LocalDate;
import java.util.List;

/**
 * One poster in the home grid or the search results. Image URLs may be null; a URL starting with
 * {@code /} is a file bundled with the backend, relative to the API base (e.g. {@code /media/posters/x.jpg}).
 */
public record MovieSummary(long id, String title, String posterUrl, String bannerUrl, String ageRating,
        int durationMin, LocalDate releaseDate, List<String> genres) {
}
