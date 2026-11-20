CREATE TABLE media_assets (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider   VARCHAR(20)  NOT NULL DEFAULT 'CLOUDINARY' CHECK (provider IN ('CLOUDINARY')),
    public_id  VARCHAR(255) NOT NULL,
    url        VARCHAR(500) NOT NULL,
    width      INTEGER,
    height     INTEGER,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (provider, public_id)
);

CREATE TABLE genres (
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE movies (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title          VARCHAR(255) NOT NULL,
    title_unaccent VARCHAR(255) NOT NULL,
    description    TEXT,
    duration_min   INTEGER      NOT NULL CHECK (duration_min > 0),
    age_rating     VARCHAR(3)   NOT NULL CHECK (age_rating IN ('P', 'K', 'T13', 'T16', 'T18')),
    release_date   DATE         NOT NULL,
    end_date       DATE,
    language       VARCHAR(50),
    trailer_url    VARCHAR(500),
    poster_id      BIGINT REFERENCES media_assets (id),
    banner_id      BIGINT REFERENCES media_assets (id),
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    CHECK (end_date IS NULL OR end_date >= release_date)
);

-- Keep the search column in sync: lower-case, accents removed ("Đất Rừng" -> "dat rung").
CREATE FUNCTION movies_set_title_unaccent() RETURNS trigger
    LANGUAGE plpgsql
AS $$
BEGIN
    NEW.title_unaccent := lower(immutable_unaccent(NEW.title));
    RETURN NEW;
END $$;

CREATE TRIGGER trg_movies_title_unaccent
    BEFORE INSERT OR UPDATE OF title ON movies
    FOR EACH ROW EXECUTE FUNCTION movies_set_title_unaccent();

CREATE TABLE movie_genres (
    movie_id BIGINT NOT NULL REFERENCES movies (id) ON DELETE CASCADE,
    genre_id BIGINT NOT NULL REFERENCES genres (id),
    PRIMARY KEY (movie_id, genre_id)
);

CREATE TABLE cinemas (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name      VARCHAR(150) NOT NULL,
    city      VARCHAR(100) NOT NULL,
    address   VARCHAR(255) NOT NULL,
    phone     VARCHAR(20),
    is_active BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (name, city)
);

CREATE TABLE auditoriums (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cinema_id BIGINT      NOT NULL REFERENCES cinemas (id),
    name      VARCHAR(50) NOT NULL,
    row_count INTEGER     NOT NULL CHECK (row_count > 0),
    col_count INTEGER     NOT NULL CHECK (col_count > 0),
    UNIQUE (cinema_id, name)
);

CREATE TABLE seat_types (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code           VARCHAR(20)  NOT NULL UNIQUE CHECK (code IN ('STANDARD', 'VIP', 'COUPLE')),
    name           VARCHAR(50)  NOT NULL,
    surcharge      INTEGER      NOT NULL DEFAULT 0 CHECK (surcharge >= 0),
    seats_per_unit INTEGER      NOT NULL DEFAULT 1 CHECK (seats_per_unit IN (1, 2))
);

CREATE TABLE seats (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    auditorium_id BIGINT     NOT NULL REFERENCES auditoriums (id),
    row_label     VARCHAR(2) NOT NULL,
    col_number    INTEGER    NOT NULL CHECK (col_number > 0),
    seat_type_id  BIGINT     NOT NULL REFERENCES seat_types (id),
    pair_seat_id  BIGINT REFERENCES seats (id),
    is_active     BOOLEAN    NOT NULL DEFAULT TRUE,
    UNIQUE (auditorium_id, row_label, col_number)
);
