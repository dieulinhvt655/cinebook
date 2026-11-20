CREATE TABLE showtimes (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    movie_id      BIGINT      NOT NULL REFERENCES movies (id),
    auditorium_id BIGINT      NOT NULL REFERENCES auditoriums (id),
    start_at      TIMESTAMPTZ NOT NULL,
    end_at        TIMESTAMPTZ NOT NULL,
    format        VARCHAR(4)  NOT NULL CHECK (format IN ('2D', '3D', 'IMAX')),
    subtitle      VARCHAR(3)  NOT NULL CHECK (subtitle IN ('SUB', 'DUB')),
    base_price    INTEGER     NOT NULL CHECK (base_price > 0),
    status        VARCHAR(10) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CANCELLED')),
    CHECK (end_at > start_at),
    -- No two open showtimes may overlap in the same auditorium.
    CONSTRAINT showtimes_no_overlap EXCLUDE USING gist (
        auditorium_id WITH =,
        tstzrange(start_at, end_at) WITH &&
    ) WHERE (status = 'OPEN')
);

CREATE TABLE combos (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255),
    price       INTEGER      NOT NULL CHECK (price > 0),
    image_id    BIGINT REFERENCES media_assets (id),
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE
);
