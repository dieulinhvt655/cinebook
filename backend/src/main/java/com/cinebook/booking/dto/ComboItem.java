package com.cinebook.booking.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/** One line of S09: a combo and how many (1–10). */
public record ComboItem(
        @NotNull(message = "Vui lòng chọn combo") Long comboId,
        @NotNull @Min(value = 1, message = "Số lượng tối thiểu là 1")
        @Max(value = 10, message = "Tối đa 10 mỗi combo") Integer quantity) {
}
