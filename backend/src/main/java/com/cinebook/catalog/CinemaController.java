package com.cinebook.catalog;

import com.cinebook.catalog.dto.CinemaInfo;
import com.cinebook.catalog.dto.City;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Cinemas")
public class CinemaController {

    private final CinemaQueryService cinemas;

    public CinemaController(CinemaQueryService cinemas) {
        this.cinemas = cinemas;
    }

    @GetMapping("/cities")
    @Operation(summary = "Thành phố có rạp đang hoạt động (chọn thành phố ở Trang chủ)")
    public List<City> cities() {
        return cinemas.cities();
    }

    @GetMapping("/cinemas")
    @Operation(summary = "Danh sách rạp (tab Rạp), lọc theo thành phố nếu truyền city")
    public List<CinemaInfo> list(@RequestParam(required = false) String city) {
        return cinemas.cinemas(city);
    }
}
