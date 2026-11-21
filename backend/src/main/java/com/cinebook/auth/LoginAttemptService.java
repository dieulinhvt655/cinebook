package com.cinebook.auth;

import com.cinebook.common.Hashing;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * BR-03: counts consecutive failed logins per e-mail and locks it temporarily with growing waits
 * (15 → 30 → 60 min by default). Works the same for e-mails without an account, so the response
 * never reveals whether an account exists (BR-03.7). Only a hash of the e-mail is stored (BR-03.6).
 */
@Service
public class LoginAttemptService {

    private static final Logger log = LoggerFactory.getLogger(LoginAttemptService.class);

    private final JdbcTemplate jdbc;
    private final AuthProperties props;
    private final Clock clock;

    public LoginAttemptService(JdbcTemplate jdbc, AuthProperties props, Clock clock) {
        this.jdbc = jdbc;
        this.props = props;
        this.clock = clock;
    }

    /** Throws {@link LoginLockedException} while the e-mail is locked. */
    public void checkNotLocked(String email) {
        List<Timestamp> lockedUntil = jdbc.queryForList(
                "SELECT locked_until FROM login_attempts WHERE subject_hash = ?", Timestamp.class, hash(email));
        Instant now = clock.instant();
        lockedUntil.stream().filter(t -> t != null && t.toInstant().isAfter(now)).findFirst()
                .ifPresent(t -> {
                    throw new LoginLockedException(Duration.between(now, t.toInstant()));
                });
    }

    /**
     * Records a failure atomically. When this failure reaches the threshold, the e-mail is locked
     * and the lock length is returned.
     */
    public Optional<Duration> recordFailure(String email) {
        Instant now = clock.instant();
        String subject = hash(email);
        int failed = jdbc.queryForObject("""
                INSERT INTO login_attempts (subject_hash, failed_count, last_failed_at) VALUES (?, 1, ?)
                ON CONFLICT (subject_hash) DO UPDATE
                   SET failed_count = login_attempts.failed_count + 1, last_failed_at = EXCLUDED.last_failed_at
                RETURNING failed_count""", Integer.class, subject, Timestamp.from(now));
        if (failed < props.maxFailedLogins()) {
            log.info("Failed login {} for account {}", failed, shortId(subject));
            return Optional.empty();
        }
        int lockNumber = jdbc.queryForObject(
                "SELECT lock_count + 1 FROM login_attempts WHERE subject_hash = ?", Integer.class, subject);
        Duration lock = props.lockDurationFor(lockNumber);
        jdbc.update("""
                UPDATE login_attempts SET failed_count = 0, lock_count = ?, locked_until = ?
                 WHERE subject_hash = ?""", lockNumber, Timestamp.from(now.plus(lock)), subject);
        log.warn("Account {} locked for {} after {} failed logins (lock #{})",
                shortId(subject), lock, failed, lockNumber);
        return Optional.of(lock);
    }

    /** A successful login clears the counter and the backoff (BR-03.4). */
    public void reset(String email) {
        jdbc.update("DELETE FROM login_attempts WHERE subject_hash = ?", hash(email));
    }

    public int deleteStale() {
        Instant cutoff = clock.instant().minus(props.attemptRetention());
        return jdbc.update("""
                DELETE FROM login_attempts
                 WHERE last_failed_at < ? AND (locked_until IS NULL OR locked_until < ?)""",
                Timestamp.from(cutoff), Timestamp.from(clock.instant()));
    }

    static String hash(String email) {
        return Hashing.sha256Hex(email);
    }

    /** Enough to correlate log lines without logging the e-mail itself. */
    private static String shortId(String subjectHash) {
        return subjectHash.substring(0, 12);
    }
}
