package com.cinebook.common;

import java.time.Duration;
import java.util.Optional;

/** Business error; the message is user-facing (Vietnamese) and ends up in ProblemDetail.detail. */
public class ApiException extends RuntimeException {

    private final ErrorCode code;
    private final Duration retryAfter;

    public ApiException(ErrorCode code, String message) {
        this(code, message, null);
    }

    /** {@code retryAfter} becomes the Retry-After header and {@code retryAfterSeconds} (e.g. 429). */
    public ApiException(ErrorCode code, String message, Duration retryAfter) {
        super(message);
        this.code = code;
        this.retryAfter = retryAfter;
    }

    public ErrorCode code() {
        return code;
    }

    public Optional<Duration> retryAfter() {
        return Optional.ofNullable(retryAfter);
    }
}
