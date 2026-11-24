# Deploy bản demo

Backend chạy trên **Render** (gói free, Docker) và dùng **PostgreSQL trên Neon** (gói free). APK được phát hành qua **GitHub Releases**. Cả hai dịch vụ đều không thu phí ở gói free. Gói free của Render cho server ngủ khi không có truy cập, nên request đầu tiên sau khi ngủ có thể mất 30–60 giây.

## 1. Database (Neon)

1. Tạo project trên [neon.tech](https://neon.tech), region **Singapore**, database tên `cinebook`.
2. Mở **SQL Editor** (đang đăng nhập bằng role owner của Neon) và chạy đoạn sau. Thay 2 mật khẩu bằng chuỗi ngẫu nhiên, ví dụ sinh bằng `openssl rand -base64 24`:

   ```sql
   CREATE ROLE cinebook_migrator LOGIN PASSWORD '<mật khẩu migrator>';
   CREATE ROLE cinebook_app LOGIN PASSWORD '<mật khẩu app>';
   CREATE EXTENSION IF NOT EXISTS unaccent;
   CREATE EXTENSION IF NOT EXISTS pg_trgm;
   CREATE EXTENSION IF NOT EXISTS btree_gist;
   ALTER SCHEMA public OWNER TO cinebook_migrator;
   GRANT USAGE ON SCHEMA public TO cinebook_app;
   ```

   Đây chính là nội dung của `backend/docker/postgres/init-roles.sql`, viết lại cho Neon. Quyền DML của `cinebook_app` do migration V1 cấp.
3. Lấy host trong **Connection Details** và ghép thành `DB_URL`:
   `jdbc:postgresql://<host>/cinebook?sslmode=require`

## 2. Backend (Render)

1. Trên Render chọn **New > Blueprint**, rồi chọn repo này. Render đọc file `render.yaml` ở thư mục gốc.
2. Điền các biến được hỏi:
   - `DB_URL`: chuỗi ở bước 1.3.
   - `DB_APP_PASSWORD`: mật khẩu của `cinebook_app`.
   - `DB_MIGRATOR_PASSWORD`: mật khẩu của `cinebook_migrator`.
   - `JWT_SECRET` và `QR_HMAC_KEY` do Render tự sinh. **Không đổi 2 giá trị này sau khi đã có người dùng:** đổi `JWT_SECRET` thì mọi phiên đăng nhập bị đăng xuất, đổi `QR_HMAC_KEY` thì mọi QR đã phát hành không còn hợp lệ.
3. Bấm **Apply**. Lần khởi động đầu tiên, Flyway chạy migration và nạp dữ liệu demo (profile `demo`).
4. Kiểm tra bằng 2 địa chỉ sau:
   - `https://<tên-service>.onrender.com/api/v1/actuator/health` phải trả `{"status":"UP"}`.
   - Swagger: `https://<tên-service>.onrender.com/api/v1/swagger-ui.html`

`autoDeploy` đang tắt. Mỗi lần muốn deploy bản mới, bấm **Manual Deploy** trên Render.

## 3. APK (GitHub Releases)

1. Trong repo GitHub, vào **Settings > Secrets and variables > Actions > Variables** và thêm biến `API_BASE_URL` = `https://<tên-service>.onrender.com/api/v1`.
2. Gắn tag rồi đẩy lên GitHub:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. Workflow `release` chạy test, build APK release trỏ tới API trên và tạo GitHub Release kèm file `cinebook-v1.0.0.apk`. Link tải bản mới nhất: `../../releases/latest`.

APK demo được ký bằng debug key, chỉ dùng để cài thử, không đưa lên Play Store.

## 4. Sau khi deploy

- Cập nhật mục **Demo** trong README: link API, link APK, GIF demo.
- Đăng nhập bằng `demo@cinebook.dev` / `Demo@1234` và chạy thử trọn luồng: chọn phim → chọn suất → chọn ghế → combo → thanh toán → xem vé.
