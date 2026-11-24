package com.cinebook.showtime.dto;

import java.time.Instant;
import java.util.List;

/**
 * S08: everything the seat picker needs in one call.
 *
 * <p>Seats are positioned by {@code col} on a {@code colCount}-wide grid; a column with no seat in
 * a row is an aisle or gap. A seat's {@code price} is the showtime base price plus its type's
 * surcharge, per seat (a couple pair costs twice that). {@code bookable} is false once online sales
 * have closed; {@code serverTime} lets the app correct its clock.
 */
public record SeatMap(long showtimeId, Instant startAt, Instant endAt, String format, String subtitle,
        int basePrice, boolean bookable, Movie movie, Venue venue, List<SeatType> seatTypes, List<SeatRow> rows,
        int availableCount, int maxSeats, Instant serverTime) {

    public record Movie(long id, String title, String ageRating, int durationMin, String posterUrl) {
    }

    public record Venue(long cinemaId, String cinemaName, long auditoriumId, String auditoriumName, int rowCount,
            int colCount) {
    }

    /** Only the types present in this room, cheapest first. */
    public record SeatType(String code, String name, int surcharge, int seatsPerUnit, int price) {
    }

    public record SeatRow(String label, List<Seat> seats) {
    }

    /** {@code pairSeatId} links the two halves of a couple seat; they are sold together. */
    public record Seat(long id, String row, int col, String type, int price, SeatStatus status, Long pairSeatId) {
    }
}
