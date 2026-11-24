package com.cinebook.catalog;

import com.cinebook.catalog.dto.CinemaInfo;
import com.cinebook.catalog.dto.City;
import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import java.util.List;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Cities and cinemas; hidden cinemas ({@code is_active = false}) never appear. */
@Service
@Transactional(readOnly = true)
public class CinemaQueryService {

    private static final String CINEMA_COLUMNS = "SELECT id, name, city, address, phone FROM cinemas WHERE is_active";

    private final JdbcClient jdbc;

    public CinemaQueryService(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public List<City> cities() {
        return jdbc.sql("SELECT city, count(*) AS n FROM cinemas WHERE is_active GROUP BY city ORDER BY city")
                .query((rs, i) -> new City(rs.getString("city"), rs.getInt("n")))
                .list();
    }

    /** All cinemas, or those of one {@code city} (exact name as returned by {@link #cities()}). */
    public List<CinemaInfo> cinemas(String city) {
        String cityFilter = city == null || city.isBlank() ? null : city.strip();
        var spec = jdbc.sql(CINEMA_COLUMNS + (cityFilter == null ? "" : " AND city = :city") + " ORDER BY city, name");
        if (cityFilter != null) {
            spec = spec.param("city", cityFilter);
        }
        return spec.query((rs, i) -> new CinemaInfo(rs.getLong("id"), rs.getString("name"), rs.getString("city"),
                rs.getString("address"), rs.getString("phone"))).list();
    }

    /** NOT_FOUND unless the cinema exists and is active. */
    public CinemaInfo require(long id) {
        return jdbc.sql(CINEMA_COLUMNS + " AND id = :id")
                .param("id", id)
                .query((rs, i) -> new CinemaInfo(rs.getLong("id"), rs.getString("name"), rs.getString("city"),
                        rs.getString("address"), rs.getString("phone")))
                .optional()
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND, "Không tìm thấy rạp"));
    }
}
