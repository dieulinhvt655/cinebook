package com.cinebook.booking;

import com.cinebook.booking.dto.BookingHistoryItem;
import com.cinebook.security.AuthUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Bookings")
public class BookingHistoryController {

    private final BookingQueryService queries;

    public BookingHistoryController(BookingQueryService queries) {
        this.queries = queries;
    }

    @GetMapping("/me/bookings")
    @Operation(summary = "Lịch sử giao dịch (S14): 50 đơn mới nhất của tôi, mọi trạng thái")
    public List<BookingHistoryItem> history(@AuthenticationPrincipal AuthUser me) {
        return queries.history(me.id());
    }
}
