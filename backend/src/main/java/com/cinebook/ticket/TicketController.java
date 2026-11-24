package com.cinebook.ticket;

import com.cinebook.security.AuthUser;
import com.cinebook.ticket.dto.TicketDetail;
import com.cinebook.ticket.dto.TicketSummary;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Tickets")
public class TicketController {

    private final TicketQueryService tickets;

    public TicketController(TicketQueryService tickets) {
        this.tickets = tickets;
    }

    @GetMapping("/me/tickets")
    @Operation(summary = "Vé của tôi (S12): scope=UPCOMING (mặc định) hoặc PAST, mua mới nhất lên đầu")
    public List<TicketSummary> mine(@AuthenticationPrincipal AuthUser me,
            @RequestParam(defaultValue = "UPCOMING") TicketScope scope) {
        return tickets.mine(me.id(), scope);
    }

    @GetMapping("/tickets/{id}")
    @Operation(summary = "Chi tiết vé (S13) theo id đơn đã thanh toán: QR có chữ ký, ghế, combo, tổng tiền")
    public TicketDetail detail(@AuthenticationPrincipal AuthUser me, @PathVariable long id) {
        return tickets.detail(me.id(), id);
    }
}
