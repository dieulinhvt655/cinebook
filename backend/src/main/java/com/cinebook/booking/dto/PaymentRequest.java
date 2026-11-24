package com.cinebook.booking.dto;

import jakarta.validation.constraints.NotNull;

/** Mock payment (S10): the user picks the outcome. A real gateway would report it in a callback. */
public record PaymentRequest(@NotNull(message = "Vui lòng chọn kết quả thanh toán") Result result) {

    public enum Result {
        SUCCESS, FAILED
    }
}
