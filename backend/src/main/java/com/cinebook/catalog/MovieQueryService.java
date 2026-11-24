package com.cinebook.catalog;

import com.cinebook.catalog.dto.MovieDetail;
import com.cinebook.catalog.dto.MovieSummary;
import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import com.cinebook.common.VietnamTime;
import java.sql.Array;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Read side of the catalogue for the app (F2, F3). Plain SQL: these are read-only projections. */
@Service
@Transactional(readOnly = true)
public class MovieQueryService {

    /** "Now showing" needs an open showtime within this many days, today included. */
    static final int SCHEDULE_DAYS = 7;
    static final int MAX_QUERY_LENGTH = 100;

    private static final String SELECT = """
            SELECT m.id, m.title, m.description, p.url AS poster_url, b.url AS banner_url, m.age_rating,
                   m.duration_min, m.release_date, m.end_date, m.language, m.trailer_url,
                   COALESCE(array_agg(g.name ORDER BY g.name) FILTER (WHERE g.id IS NOT NULL), '{}') AS genres
              FROM movies m
              LEFT JOIN media_assets p ON p.id = m.poster_id
              LEFT JOIN media_assets b ON b.id = m.banner_id
              LEFT JOIN movie_genres mg ON mg.movie_id = m.id
              LEFT JOIN genres g ON g.id = mg.genre_id
             WHERE m.is_active
            """;
    private static final String GROUP_BY = " GROUP BY m.id, p.url, b.url ";

    private final JdbcClient jdbc;
    private final Clock clock;

    public MovieQueryService(JdbcClient jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    /**
     * Home tabs and search. With a query, every active movie whose title matches is returned
     * (accents and case ignored: "avengers", "dat rung"), narrowed to {@code status} if given;
     * without one, {@code status} defaults to NOW_SHOWING.
     */
    public List<MovieSummary> list(MovieStatus status, String query) {
        return list(status, query, null);
    }

    /**
     * As {@link #list(MovieStatus, String)}; with a {@code city}, "now showing" only counts showtimes
     * at active cinemas of that city (Home city picker). Coming-soon movies are not tied to a city.
     */
    public List<MovieSummary> list(MovieStatus status, String query, String city) {
        String cityFilter = city == null || city.isBlank() ? null : city.strip();
        String q = query == null ? "" : query.strip();
        if (q.length() > MAX_QUERY_LENGTH) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED, "Từ khoá tìm kiếm tối đa " + MAX_QUERY_LENGTH + " ký tự");
        }
        MovieStatus effective = status == null && q.isEmpty() ? MovieStatus.NOW_SHOWING : status;

        LocalDate today = VietnamTime.today(clock);
        StringBuilder sql = new StringBuilder(SELECT);
        if (!q.isEmpty()) {
            sql.append(" AND m.title_unaccent LIKE '%' || lower(immutable_unaccent(:q)) || '%' ESCAPE '\\' ");
        }
        if (effective == MovieStatus.NOW_SHOWING) {
            sql.append("""
                     AND m.release_date <= :today
                     AND EXISTS (SELECT 1 FROM showtimes s
                                  WHERE s.movie_id = m.id AND s.status = 'OPEN'
                                    AND s.start_at > :now AND s.start_at < :horizon
                    """).append(cityFilter == null ? "" : """
                                    AND s.auditorium_id IN (SELECT a.id FROM auditoriums a
                                                              JOIN cinemas c ON c.id = a.cinema_id
                                                             WHERE c.city = :city AND c.is_active)
                    """).append(")\n");
        } else if (effective == MovieStatus.COMING_SOON) {
            sql.append(" AND m.release_date > :today ");
        }
        sql.append(GROUP_BY).append(effective == MovieStatus.COMING_SOON
                ? " ORDER BY m.release_date, m.title"
                : " ORDER BY m.release_date DESC, m.title");

        var spec = jdbc.sql(sql.toString()).param("today", today);
        if (!q.isEmpty()) {
            spec = spec.param("q", escapeLike(q));
        }
        if (effective == MovieStatus.NOW_SHOWING) {
            spec = spec.param("now", OffsetDateTime.now(clock).withOffsetSameInstant(ZoneOffset.UTC))
                    .param("horizon", today.plusDays(SCHEDULE_DAYS).atStartOfDay(VietnamTime.ZONE).toOffsetDateTime());
            if (cityFilter != null) {
                spec = spec.param("city", cityFilter);
            }
        }
        return spec.query((rs, i) -> new MovieSummary(rs.getLong("id"), rs.getString("title"),
                rs.getString("poster_url"), rs.getString("banner_url"), rs.getString("age_rating"),
                rs.getInt("duration_min"), rs.getObject("release_date", LocalDate.class), genres(rs))).list();
    }

    public MovieDetail detail(long id) {
        return jdbc.sql(SELECT + " AND m.id = :id" + GROUP_BY)
                .param("id", id)
                .query((rs, i) -> new MovieDetail(rs.getLong("id"), rs.getString("title"), rs.getString("description"),
                        rs.getString("poster_url"), rs.getString("banner_url"), rs.getString("age_rating"),
                        rs.getInt("duration_min"), rs.getObject("release_date", LocalDate.class),
                        rs.getObject("end_date", LocalDate.class), rs.getString("language"),
                        rs.getString("trailer_url"), genres(rs)))
                .optional()
                .orElseThrow(() -> notFound());
    }

    /** Throws NOT_FOUND unless the movie exists and is active. */
    public void requireActive(long id) {
        boolean exists = jdbc.sql("SELECT EXISTS (SELECT 1 FROM movies WHERE id = :id AND is_active)")
                .param("id", id).query(Boolean.class).single();
        if (!exists) {
            throw notFound();
        }
    }

    private static ApiException notFound() {
        return new ApiException(ErrorCode.NOT_FOUND, "Không tìm thấy phim");
    }

    /** User input is matched literally: % and _ are not wildcards. */
    static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }

    private static List<String> genres(ResultSet rs) throws SQLException {
        Array array = rs.getArray("genres");
        return List.of((String[]) array.getArray());
    }
}
