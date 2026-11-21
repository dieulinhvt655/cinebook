package com.cinebook.common;

import org.springframework.http.HttpStatus;

/** Machine-readable error codes, returned as the {@code code} property of a ProblemDetail (RFC 9457). */
public enum ErrorCode {
    VALIDATION_FAILED(HttpStatus.BAD_REQUEST),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED),
    INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED),
    REFRESH_TOKEN_INVALID(HttpStatus.UNAUTHORIZED),
    TOO_MANY_LOGIN_ATTEMPTS(HttpStatus.TOO_MANY_REQUESTS),
    FORBIDDEN(HttpStatus.FORBIDDEN),
    NOT_FOUND(HttpStatus.NOT_FOUND),
    EMAIL_TAKEN(HttpStatus.CONFLICT),
    SHOWTIME_CLOSED(HttpStatus.CONFLICT),
    SEAT_TAKEN(HttpStatus.CONFLICT),
    SEAT_LIMIT_EXCEEDED(HttpStatus.UNPROCESSABLE_ENTITY),
    ORPHAN_SEAT(HttpStatus.UNPROCESSABLE_ENTITY),
    COUPLE_SEAT_SPLIT(HttpStatus.UNPROCESSABLE_ENTITY),
    HOLD_EXPIRED(HttpStatus.GONE),
    BOOKING_NOT_HOLDING(HttpStatus.CONFLICT),
    IDEMPOTENCY_KEY_REQUIRED(HttpStatus.BAD_REQUEST),
    PAYMENT_FAILED(HttpStatus.PAYMENT_REQUIRED),
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR);

    private final HttpStatus status;

    ErrorCode(HttpStatus status) {
        this.status = status;
    }

    public HttpStatus status() {
        return status;
    }
}
