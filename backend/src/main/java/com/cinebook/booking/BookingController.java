package com.cinebook.booking;

import com.cinebook.booking.dto.BookingView;
import com.cinebook.booking.dto.ComboSelection;
import com.cinebook.booking.dto.HoldRequest;
import com.cinebook.booking.dto.PaymentRequest;
import com.cinebook.booking.dto.PaymentView;
import com.cinebook.security.AuthUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/bookings")
@Tag(name = "Bookings")
public class BookingController {

    private final SeatHoldService holds;
    private final BookingQueryService queries;
    private final ComboService combos;
    private final PaymentService payments;

    public BookingController(SeatHoldService holds, BookingQueryService queries, ComboService combos,
            PaymentService payments) {
        this.holds = holds;
        this.queries = queries;
        this.combos = combos;
        this.payments = payments;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Giữ ghế 10 phút (S08 \"Tiếp tục\"). 409 SEAT_TAKEN nếu ghế vừa bị người khác giữ")
    public BookingView hold(@AuthenticationPrincipal AuthUser me, @Valid @RequestBody HoldRequest request) {
        return holds.hold(me.id(), request);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Đơn của tôi: ghế, giá đã chốt, hạn giữ ghế")
    public BookingView get(@AuthenticationPrincipal AuthUser me, @PathVariable long id) {
        return queries.view(me.id(), id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Huỷ giữ ghế, nhả ghế ngay")
    public void cancel(@AuthenticationPrincipal AuthUser me, @PathVariable long id) {
        holds.cancel(me.id(), id);
    }

    @PutMapping("/{id}/combos")
    @Operation(summary = "Chọn combo cho đơn đang giữ (S09), thay danh sách cũ. 410 HOLD_EXPIRED nếu hết giờ")
    public BookingView combos(@AuthenticationPrincipal AuthUser me, @PathVariable long id,
            @Valid @RequestBody ComboSelection selection) {
        return combos.replace(me.id(), id, selection.items());
    }

    @PostMapping("/{id}/payments")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Thanh toán giả lập (S10). Bắt buộc header Idempotency-Key; gửi lại cùng key trả về "
            + "cùng giao dịch. 410 HOLD_EXPIRED nếu hết giờ giữ ghế")
    public PaymentView pay(@AuthenticationPrincipal AuthUser me, @PathVariable long id,
            @RequestHeader(name = "Idempotency-Key", required = false) String idempotencyKey,
            @Valid @RequestBody PaymentRequest request) {
        return payments.pay(me.id(), id, idempotencyKey, request.result());
    }
}
