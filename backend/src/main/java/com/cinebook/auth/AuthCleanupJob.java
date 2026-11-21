package com.cinebook.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Daily housekeeping: expired refresh tokens and stale failed-login records. */
@Component
public class AuthCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(AuthCleanupJob.class);

    private final RefreshTokenService refreshTokens;
    private final LoginAttemptService attempts;

    public AuthCleanupJob(RefreshTokenService refreshTokens, LoginAttemptService attempts) {
        this.refreshTokens = refreshTokens;
        this.attempts = attempts;
    }

    @Scheduled(cron = "${cinebook.auth.cleanup-cron}", zone = "Asia/Ho_Chi_Minh")
    public void run() {
        int tokens = refreshTokens.deleteExpired();
        int stale = attempts.deleteStale();
        log.info("Auth cleanup: {} expired refresh token(s), {} stale login attempt record(s)", tokens, stale);
    }
}
