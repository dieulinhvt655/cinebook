package com.cinebook.auth;

import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import java.time.Duration;

/** Login refused during a temporary lock (BR-03.3); the response carries Retry-After. */
public class LoginLockedException extends ApiException {

    public LoginLockedException(Duration retryAfter) {
        super(ErrorCode.TOO_MANY_LOGIN_ATTEMPTS, "Bạn đã đăng nhập sai quá nhiều lần. Vui lòng thử lại sau "
                + Math.max(1, (retryAfter.toSeconds() + 59) / 60) + " phút", retryAfter);
    }
}
