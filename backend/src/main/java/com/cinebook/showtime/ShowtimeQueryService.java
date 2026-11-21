package com.cinebook.showtime;

import com.cinebook.booking.BookingProperties;
import com.cinebook.catalog.MovieQueryService;
import com.cinebook.common.VietnamTime;
import com.cinebook.showtime.dto.CinemaShowtimes;
import com.cinebook.showtime.dto.MovieShowtimes;
import com.cinebook.showtime.dto.ShowtimeSlot;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** S07: showtimes of a movie for one day (Vietnam date), grouped by cinema. */
@Service
@Transactional(readOnly = true)
public class ShowtimeQueryService {

    private static final String FROM = """
              FROM showtimes s
              JOIN auditoriums a ON a.id = s.auditorium_id
              JOIN cinemas c ON c.id = a.cinema_id
             WHERE s.movie_id = :movieId AND s.status = 'OPEN' AND c.is_active
               AND s.start_at > :now
            """;

    private final JdbcClient jdbc;
    private final Clock clock;
    private final BookingProperties booking;
    private final MovieQueryService movies;

    public ShowtimeQueryService(JdbcClient jdbc, Clock clock, BookingProperties booking, MovieQueryService movies) {
        this.jdbc = jdbc;
        this.clock = clock;
        this.booking = booking;
        this.movies = movies;
    }

    /**
     * Started showtimes are hidden; those starting within the sales cutoff are listed but not
     * bookable. {@code date} defaults to today, {@code city} (exact cinema city) is optional.
     */
    public MovieShowtimes forMovie(long movieId, LocalDate date, String city) {
        movies.requireActive(movieId);
        LocalDate day = date == null ? VietnamTime.today(clock) : date;
        String cityFilter = city == null || city.isBlank() ? null : city.strip();
        OffsetDateTime now = OffsetDateTime.now(clock).withOffsetSameInstant(ZoneOffset.UTC);
        OffsetDateTime dayStart = day.atStartOfDay(VietnamTime.ZONE).toOffsetDateTime();
        OffsetDateTime dayEnd = day.plusDays(1).atStartOfDay(VietnamTime.ZONE).toOffsetDateTime();
        Instant salesCloseAfter = now.toInstant().plus(booking.salesCutoff());
        String cityClause = cityFilter == null ? "" : " AND c.city = :city ";

        var spec = jdbc.sql("""
                SELECT c.id AS cinema_id, c.name AS cinema_name, c.city, c.address,
                       s.id, s.start_at, s.end_at, s.format, s.subtitle, a.name AS auditorium, s.base_price
                """ + FROM + cityClause + """
                   AND s.start_at >= :dayStart AND s.start_at < :dayEnd
                 ORDER BY c.name, c.id, s.start_at, a.name
                """)
                .param("movieId", movieId).param("now", now)
                .param("dayStart", dayStart).param("dayEnd", dayEnd);
        if (cityFilter != null) {
            spec = spec.param("city", cityFilter);
        }

        Map<Long, CinemaBuilder> byCinema = new LinkedHashMap<>();
        spec.query(rs -> {
            Instant start = rs.getObject("start_at", OffsetDateTime.class).toInstant();
            long cinemaId = rs.getLong("cinema_id");
            CinemaBuilder cinema = byCinema.get(cinemaId);
            if (cinema == null) {
                cinema = new CinemaBuilder(cinemaId, rs.getString("cinema_name"), rs.getString("city"),
                        rs.getString("address"));
                byCinema.put(cinemaId, cinema);
            }
            cinema.slots.add(new ShowtimeSlot(rs.getLong("id"), start,
                    rs.getObject("end_at", OffsetDateTime.class).toInstant(), rs.getString("format"),
                    rs.getString("subtitle"), rs.getString("auditorium"), rs.getInt("base_price"),
                    start.isAfter(salesCloseAfter)));
        });

        List<CinemaShowtimes> cinemas = byCinema.values().stream().map(CinemaBuilder::build).toList();
        LocalDate next = cinemas.isEmpty() ? nextDateWithShowtimes(movieId, dayEnd, now, cityFilter, cityClause) : null;
        return new MovieShowtimes(movieId, day, cinemas, next);
    }

    private LocalDate nextDateWithShowtimes(long movieId, OffsetDateTime after, OffsetDateTime now, String city,
            String cityClause) {
        var spec = jdbc.sql("SELECT min(s.start_at) " + FROM + cityClause + " AND s.start_at >= :after")
                .param("movieId", movieId).param("now", now).param("after", after);
        if (city != null) {
            spec = spec.param("city", city);
        }
        OffsetDateTime first = spec.query(OffsetDateTime.class).optional().orElse(null);
        return first == null ? null : first.atZoneSameInstant(VietnamTime.ZONE).toLocalDate();
    }

    private static final class CinemaBuilder {
        private final long id;
        private final String name;
        private final String city;
        private final String address;
        private final List<ShowtimeSlot> slots = new ArrayList<>();

        CinemaBuilder(long id, String name, String city, String address) {
            this.id = id;
            this.name = name;
            this.city = city;
            this.address = address;
        }

        CinemaShowtimes build() {
            return new CinemaShowtimes(id, name, city, address, List.copyOf(slots));
        }
    }
}
