package com.cinebook.showtime;

import com.cinebook.showtime.dto.MovieShowtimes;
import com.cinebook.showtime.dto.SeatMap;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.LocalDate;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Showtimes")
public class ShowtimeController {

    private final ShowtimeQueryService showtimes;
    private final SeatMapQueryService seatMaps;

    public ShowtimeController(ShowtimeQueryService showtimes, SeatMapQueryService seatMaps) {
        this.showtimes = showtimes;
        this.seatMaps = seatMaps;
    }

    @GetMapping("/movies/{id}/showtimes")
    @Operation(summary = "Suất chiếu của phim trong một ngày (giờ Việt Nam, mặc định hôm nay), nhóm theo rạp (S07). "
            + "Suất đã chiếu bị ẩn; bookable=false khi còn dưới 15 phút. Ngày trống thì nextAvailableDate gợi ý ngày gần nhất")
    public MovieShowtimes forMovie(@PathVariable long id,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) String city) {
        return showtimes.forMovie(id, date, city);
    }

    @GetMapping("/showtimes/{id}/seats")
    @Operation(summary = "Sơ đồ ghế của suất chiếu (S08): ghế theo hàng, loại, giá (giá suất + phụ thu), trạng thái "
            + "AVAILABLE/HELD/SOLD. Hold đã quá hạn được tính là trống. Suất đã đóng bán vẫn trả về với bookable=false")
    public SeatMap seats(@PathVariable long id) {
        return seatMaps.forShowtime(id);
    }
}
