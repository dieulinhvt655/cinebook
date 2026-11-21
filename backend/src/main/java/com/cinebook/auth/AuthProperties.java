package com.cinebook.auth;

import java.time.Duration;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param maxFailedLogins  consecutive failures allowed before a temporary lock (BR-03.1)
 * @param lockDurations    lock length for the 1st, 2nd, ... lock; the last value repeats (BR-03.2)
 * @param attemptRetention failure records older than this are dropped by {@link AuthCleanupJob}
 * @param cleanupCron      when {@link AuthCleanupJob} runs
 */
@ConfigurationProperties(prefix = "cinebook.auth")
public record AuthProperties(int maxFailedLogins, List<Duration> lockDurations, Duration attemptRetention,
        String cleanupCron) {

    public Duration lockDurationFor(int lockNumber) {
        int i = Math.min(Math.max(lockNumber, 1), lockDurations.size()) - 1;
        return lockDurations.get(i);
    }
}
