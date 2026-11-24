package com.cinebook.booking.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.util.List;

/** "Tiếp tục" on S08: hold these seats of the showtime. Both halves of a couple seat must be listed. */
public record HoldRequest(
        @NotNull(message = "Vui lòng chọn suất chiếu") Long showtimeId,
        @NotEmpty(message = "Vui lòng chọn ít nhất 1 ghế") List<@NotNull Long> seatIds) {
}
