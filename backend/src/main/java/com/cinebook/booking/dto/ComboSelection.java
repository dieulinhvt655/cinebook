package com.cinebook.booking.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.util.List;

/** S09 "Tiếp tục": the booking's combos, replacing any picked before. Empty = no combo. */
public record ComboSelection(@NotNull(message = "Thiếu danh sách combo") List<@Valid @NotNull ComboItem> items) {
}
