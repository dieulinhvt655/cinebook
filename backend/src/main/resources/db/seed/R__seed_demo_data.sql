-- Demo seed (repeatable). Loaded only by the dev/demo profiles (flyway locations include db/seed).
-- The placeholder below changes on every run, so Flyway re-applies this file at each startup:
-- static catalogue rows are inserted once, showtimes are topped up for the next 7 days.
-- run: ${flyway:timestamp}

DO $$
DECLARE
    v_cinema   BIGINT;
    v_aud      BIGINT;
    v_std      BIGINT;
    v_vip      BIGINT;
    v_couple   BIGINT;
    r_idx      INT;
    c          INT;
    rows_lbl   TEXT[] := ARRAY['A','B','C','D','E','F','G','H','I','J'];
BEGIN
    IF EXISTS (SELECT 1 FROM cinemas) THEN
        RETURN; -- catalogue already seeded
    END IF;

    -- Demo accounts, password for all: Demo@1234
    INSERT INTO users (email, password_hash, full_name, phone, date_of_birth, role) VALUES
        ('demo@cinebook.dev',  '$2a$10$wUgbW7BEDXz3Ne1CNLtJ7OWbAcIV8dfXbXqbfNYxy0jODhwa6bgQ6', 'Khách Demo',  '0900000001', '2000-01-15', 'CUSTOMER'),
        ('demo2@cinebook.dev', '$2a$10$wUgbW7BEDXz3Ne1CNLtJ7OWbAcIV8dfXbXqbfNYxy0jODhwa6bgQ6', 'Khách Demo 2', '0900000002', '1998-06-20', 'CUSTOMER'),
        ('admin@cinebook.dev', '$2a$10$wUgbW7BEDXz3Ne1CNLtJ7OWbAcIV8dfXbXqbfNYxy0jODhwa6bgQ6', 'Quản trị',     '0900000003', '1990-03-01', 'ADMIN'),
        ('staff@cinebook.dev', '$2a$10$wUgbW7BEDXz3Ne1CNLtJ7OWbAcIV8dfXbXqbfNYxy0jODhwa6bgQ6', 'Nhân viên',    '0900000004', '1995-09-09', 'STAFF');

    INSERT INTO seat_types (code, name, surcharge, seats_per_unit) VALUES
        ('STANDARD', 'Thường', 0, 1),
        ('VIP', 'VIP', 15000, 1),
        ('COUPLE', 'Ghế đôi', 30000, 2);
    SELECT id INTO v_std    FROM seat_types WHERE code = 'STANDARD';
    SELECT id INTO v_vip    FROM seat_types WHERE code = 'VIP';
    SELECT id INTO v_couple FROM seat_types WHERE code = 'COUPLE';

    INSERT INTO genres (name) VALUES
        ('Hành động'), ('Hài'), ('Tâm lý'), ('Kinh dị'), ('Hoạt hình'),
        ('Khoa học viễn tưởng'), ('Phiêu lưu'), ('Lãng mạn');

    INSERT INTO cinemas (name, city, address, phone) VALUES
        ('CineBook Tràng Tiền', 'Hà Nội',        '1 Tràng Tiền, Hoàn Kiếm, Hà Nội',     '02400000001'),
        ('CineBook Cầu Giấy',   'Hà Nội',        '99 Xuân Thủy, Cầu Giấy, Hà Nội',      '02400000002'),
        ('CineBook Nguyễn Huệ', 'TP. Hồ Chí Minh', '45 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', '02800000001');

    -- 3 rooms per cinema, rows A–J x 12 columns: A–E standard, F–I VIP (middle), J = 6 couple pairs.
    FOR v_cinema IN SELECT id FROM cinemas ORDER BY id LOOP
        FOR a IN 1..3 LOOP
            INSERT INTO auditoriums (cinema_id, name, row_count, col_count)
            VALUES (v_cinema, 'Phòng ' || a, 10, 12)
            RETURNING id INTO v_aud;

            FOR r_idx IN 1..10 LOOP
                FOR c IN 1..12 LOOP
                    INSERT INTO seats (auditorium_id, row_label, col_number, seat_type_id)
                    VALUES (v_aud, rows_lbl[r_idx], c,
                            CASE WHEN r_idx = 10 THEN v_couple
                                 WHEN r_idx >= 6 THEN v_vip
                                 ELSE v_std END);
                END LOOP;
            END LOOP;

            -- Pair couple seats J1-J2, J3-J4, ...
            UPDATE seats s SET pair_seat_id = p.id
              FROM seats p
             WHERE s.auditorium_id = v_aud AND p.auditorium_id = v_aud
               AND s.row_label = 'J' AND p.row_label = 'J'
               AND p.col_number = CASE WHEN s.col_number % 2 = 1 THEN s.col_number + 1
                                       ELSE s.col_number - 1 END;
        END LOOP;
    END LOOP;

    -- 9 now showing, 3 coming soon. Durations <= 165 min so they fit the 3-hour slots below.
    INSERT INTO movies (title, title_unaccent, description, duration_min, age_rating, release_date, end_date, language, trailer_url) VALUES
        ('Ánh Sao Cuối Trời',     '', 'Phi hành đoàn chạy đua cứu một ngôi sao đang tắt.',        128, 'T13', current_date - 20, current_date + 40, 'Tiếng Anh', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        ('Bến Phà Cuối Cùng',     '', 'Câu chuyện lặng lẽ của người lái phà trên sông Hậu.',       104, 'P',   current_date - 15, current_date + 30, 'Tiếng Việt', NULL),
        ('Chợ Đêm',               '', 'Một phi vụ táo bạo giữa khu chợ đêm đông đúc nhất Sài Gòn.', 116, 'T16', current_date - 6,  current_date + 45, 'Tiếng Việt', NULL),
        ('Avengers of the Abyss', '', 'Liên minh thợ lặn đối đầu sinh vật dưới đáy đại dương.',     142, 'T13', current_date - 10, current_date + 35, 'Tiếng Anh', NULL),
        ('Nhà Bà Nội Có Ma',      '', 'Kỳ nghỉ hè ở quê biến thành chuỗi đêm mất ngủ.',              98, 'T18', current_date - 3,  current_date + 30, 'Tiếng Việt', NULL),
        ('Mèo Mây Phiêu Lưu Ký',  '', 'Chú mèo nhỏ cưỡi mây đi tìm mẹ.',                             92, 'P',   current_date - 25, current_date + 20, 'Lồng tiếng', NULL),
        ('Hẹn Em Ngày Nắng',      '', 'Hai người lạ gặp nhau trên chuyến tàu Bắc – Nam.',            110, 'K',   current_date - 8,  current_date + 30, 'Tiếng Việt', NULL),
        ('Tốc Độ Tối Thượng',     '', 'Tay đua đường phố nhận phi vụ cuối cùng.',                   135, 'T16', current_date - 2,  current_date + 50, 'Tiếng Anh', NULL),
        ('Ông Ngoại Siêu Hài',    '', 'Ông ngoại 70 tuổi quyết định đi thi hoa hậu… quý ông.',      101, 'K',   current_date - 12, current_date + 25, 'Tiếng Việt', NULL),
        ('Thành Phố Máy',         '', 'Năm 2099, một kỹ sư phát hiện thành phố có ý thức.',         150, 'T13', current_date + 5,  current_date + 60, 'Tiếng Anh', NULL),
        ('Mùa Hoa Gạo',           '', 'Mối tình đầu dưới gốc gạo làng.',                             105, 'P',   current_date + 12, current_date + 60, 'Tiếng Việt', NULL),
        ('Đảo Không Tên',         '', 'Năm người sống sót trên hòn đảo không có trên bản đồ.',      124, 'T16', current_date + 20, current_date + 80, 'Tiếng Anh', NULL);

    INSERT INTO movie_genres (movie_id, genre_id)
    SELECT m.id, g.id FROM movies m JOIN genres g ON
        (m.title IN ('Ánh Sao Cuối Trời', 'Thành Phố Máy') AND g.name = 'Khoa học viễn tưởng') OR
        (m.title IN ('Chợ Đêm', 'Avengers of the Abyss', 'Tốc Độ Tối Thượng') AND g.name = 'Hành động') OR
        (m.title IN ('Bến Phà Cuối Cùng', 'Hẹn Em Ngày Nắng') AND g.name = 'Tâm lý') OR
        (m.title = 'Nhà Bà Nội Có Ma' AND g.name = 'Kinh dị') OR
        (m.title = 'Mèo Mây Phiêu Lưu Ký' AND g.name = 'Hoạt hình') OR
        (m.title IN ('Ông Ngoại Siêu Hài') AND g.name = 'Hài') OR
        (m.title IN ('Mùa Hoa Gạo', 'Hẹn Em Ngày Nắng') AND g.name = 'Lãng mạn') OR
        (m.title IN ('Đảo Không Tên', 'Avengers of the Abyss', 'Mèo Mây Phiêu Lưu Ký') AND g.name = 'Phiêu lưu');

    INSERT INTO combos (name, description, price) VALUES
        ('Combo Solo',   '1 bắp ngọt (M) + 1 nước ngọt (L)',  79000),
        ('Combo Couple', '1 bắp ngọt (L) + 2 nước ngọt (L)', 109000),
        ('Combo Family', '2 bắp (L) + 4 nước ngọt (M)',     189000),
        ('Nước suối',    '1 chai 500 ml',                     20000);
END $$;

-- Showtimes for the next 7 days (Vietnam time), 5 slots per room, about 300 in total.
-- Re-runs only fill in missing slots: the overlap exclusion constraint makes duplicates a no-op.
INSERT INTO showtimes (movie_id, auditorium_id, start_at, end_at, format, subtitle, base_price)
SELECT m.id,
       a.id,
       slot.start_at,
       slot.start_at + make_interval(mins => m.duration_min),
       fmt.format,
       CASE WHEN (a.id + d.day) % 3 = 0 THEN 'DUB' ELSE 'SUB' END,
       CASE WHEN extract(isodow FROM slot.start_at AT TIME ZONE 'Asia/Ho_Chi_Minh') >= 6 THEN 95000 ELSE 80000 END
         + CASE fmt.format WHEN '3D' THEN 20000 WHEN 'IMAX' THEN 50000 ELSE 0 END
FROM auditoriums a
CROSS JOIN generate_series(0, 6) AS d(day)
CROSS JOIN unnest(ARRAY[9, 12, 15, 18, 21]) WITH ORDINALITY AS h(hour, slot_no)
CROSS JOIN LATERAL (
    SELECT ((current_date + d.day)::timestamp + make_interval(hours => h.hour))
               AT TIME ZONE 'Asia/Ho_Chi_Minh' AS start_at
) slot
CROSS JOIN LATERAL (
    SELECT CASE WHEN a.name = 'Phòng 3' AND a.cinema_id = (SELECT min(id) FROM cinemas) THEN 'IMAX'
                WHEN a.name = 'Phòng 2' THEN '3D'
                ELSE '2D' END AS format
) fmt
CROSS JOIN LATERAL (
    SELECT mv.id, mv.duration_min
      FROM (SELECT id, duration_min, row_number() OVER (ORDER BY id) - 1 AS rn, count(*) OVER () AS n
              FROM movies
             WHERE is_active AND release_date <= current_date + d.day
               AND (end_date IS NULL OR end_date >= current_date + d.day)) mv
     WHERE mv.rn = (a.id + d.day * 5 + h.slot_no) % mv.n
) m
WHERE slot.start_at > now()
ON CONFLICT DO NOTHING;
