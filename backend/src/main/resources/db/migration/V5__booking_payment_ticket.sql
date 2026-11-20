CREATE TABLE bookings (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_code VARCHAR(12) NOT NULL UNIQUE,
    user_id      BIGINT      NOT NULL REFERENCES users (id),
    showtime_id  BIGINT      NOT NULL REFERENCES showtimes (id),
    status       VARCHAR(10) NOT NULL
                 CHECK (status IN ('HOLDING', 'PAID', 'EXPIRED', 'CANCELLED')),
    seat_total   INTEGER     NOT NULL CHECK (seat_total >= 0),
    combo_total  INTEGER     NOT NULL DEFAULT 0 CHECK (combo_total >= 0),
    total_amount INTEGER     NOT NULL,
    expires_at   TIMESTAMPTZ NOT NULL,
    paid_at      TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (total_amount = seat_total + combo_total)
);

-- showtime_id is denormalised on purpose so the partial unique index below is possible.
CREATE TABLE booking_seats (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id     BIGINT      NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
    showtime_id    BIGINT      NOT NULL REFERENCES showtimes (id),
    seat_id        BIGINT      NOT NULL REFERENCES seats (id),
    seat_type_code VARCHAR(20) NOT NULL,
    price          INTEGER     NOT NULL CHECK (price > 0),
    is_active      BOOLEAN     NOT NULL DEFAULT TRUE
);

-- The anti double-booking lock: at most one active row per (showtime, seat).
CREATE UNIQUE INDEX uq_booking_seats_active
    ON booking_seats (showtime_id, seat_id) WHERE is_active;

CREATE TABLE booking_combos (
    booking_id BIGINT  NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
    combo_id   BIGINT  NOT NULL REFERENCES combos (id),
    quantity   INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 10),
    unit_price INTEGER NOT NULL CHECK (unit_price > 0),
    PRIMARY KEY (booking_id, combo_id)
);

CREATE TABLE payments (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id      BIGINT       NOT NULL REFERENCES bookings (id),
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    method          VARCHAR(10)  NOT NULL CHECK (method IN ('MOCK', 'VIETQR')),
    amount          INTEGER      NOT NULL CHECK (amount > 0),
    status          VARCHAR(10)  NOT NULL CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED')),
    provider_ref    VARCHAR(100),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE tickets (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id      BIGINT      NOT NULL REFERENCES bookings (id),
    booking_seat_id BIGINT      NOT NULL UNIQUE REFERENCES booking_seats (id),
    ticket_code     VARCHAR(16) NOT NULL UNIQUE,
    qr_payload      VARCHAR(255) NOT NULL,
    status          VARCHAR(10) NOT NULL DEFAULT 'VALID' CHECK (status IN ('VALID', 'USED', 'VOID')),
    checked_in_at   TIMESTAMPTZ,
    checked_in_by   BIGINT REFERENCES users (id)
);
