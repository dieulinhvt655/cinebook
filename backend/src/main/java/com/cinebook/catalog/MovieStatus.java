package com.cinebook.catalog;

/** Home tabs (F2). */
public enum MovieStatus {
    /** Released (release date ≤ today) and has an open showtime in the next 7 days. */
    NOW_SHOWING,
    /** Release date after today. */
    COMING_SOON
}
