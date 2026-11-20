CREATE INDEX idx_showtimes_movie_start      ON showtimes (movie_id, start_at);
CREATE INDEX idx_showtimes_auditorium_start ON showtimes (auditorium_id, start_at);
CREATE INDEX idx_bookings_user_created      ON bookings (user_id, created_at DESC);
CREATE INDEX idx_bookings_holding_expiry    ON bookings (status, expires_at) WHERE status = 'HOLDING';
CREATE INDEX idx_booking_seats_showtime     ON booking_seats (showtime_id) WHERE is_active;
CREATE INDEX idx_movies_title_trgm          ON movies USING gin (title_unaccent gin_trgm_ops);
CREATE INDEX idx_refresh_tokens_user        ON refresh_tokens (user_id);
