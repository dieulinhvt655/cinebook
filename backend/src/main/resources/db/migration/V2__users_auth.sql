CREATE TABLE users (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE CHECK (email = lower(email)),
    password_hash VARCHAR(100) NOT NULL,
    full_name     VARCHAR(150) NOT NULL,
    phone         VARCHAR(20),
    date_of_birth DATE,
    role          VARCHAR(20)  NOT NULL DEFAULT 'CUSTOMER'
                  CHECK (role IN ('CUSTOMER', 'ADMIN', 'STAFF')),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Only the SHA-256 hash of the refresh token is stored. Tokens rotate on every refresh;
-- re-use of a revoked token revokes its whole family.
CREATE TABLE refresh_tokens (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash CHAR(64)    NOT NULL UNIQUE,
    family_id  UUID        NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
