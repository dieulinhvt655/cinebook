package com.cinebook.common;

/** Business error; the message is user-facing (Vietnamese) and ends up in ProblemDetail.detail. */
public class ApiException extends RuntimeException {

    private final ErrorCode code;

    public ApiException(ErrorCode code, String message) {
        super(message);
        this.code = code;
    }

    public ErrorCode code() {
        return code;
    }
}
