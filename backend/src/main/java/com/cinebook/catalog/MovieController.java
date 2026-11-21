package com.cinebook.catalog;

import com.cinebook.catalog.dto.MovieDetail;
import com.cinebook.catalog.dto.MovieSummary;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/movies")
@Tag(name = "Movies")
public class MovieController {

    private final MovieQueryService movies;

    public MovieController(MovieQueryService movies) {
        this.movies = movies;
    }

    @GetMapping
    @Operation(summary = "Tab Đang chiếu / Sắp chiếu (S04) và tìm kiếm theo tên (S05), không phân biệt dấu và hoa thường. "
            + "Không có q thì status mặc định NOW_SHOWING; có q thì tìm mọi phim, lọc thêm theo status nếu truyền")
    public List<MovieSummary> list(@RequestParam(required = false) MovieStatus status,
            @RequestParam(required = false) String q) {
        return movies.list(status, q);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Chi tiết phim (S06). 404 NOT_FOUND nếu không có hoặc đã ẩn")
    public MovieDetail detail(@PathVariable long id) {
        return movies.detail(id);
    }
}
