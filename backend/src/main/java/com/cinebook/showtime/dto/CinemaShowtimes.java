package com.cinebook.showtime.dto;

import java.util.List;

public record CinemaShowtimes(long cinemaId, String name, String city, String address,
        List<ShowtimeSlot> showtimes) {
}
