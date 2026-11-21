-- BR-03: throttle failed logins per account identifier. Keyed by SHA-256 of the lower-cased email,
-- so it also tracks e-mails that have no account (no account enumeration, BR-03.7) and stores no PII.
CREATE TABLE login_attempts (
    subject_hash   CHAR(64)    PRIMARY KEY,
    failed_count   INT         NOT NULL DEFAULT 0,
    lock_count     INT         NOT NULL DEFAULT 0,
    locked_until   TIMESTAMPTZ,
    last_failed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_login_attempts_last_failed ON login_attempts (last_failed_at);
