## Mô tả

<!-- Thay đổi gì, vì sao. Liên kết màn hình (S01–S14) hoặc mục trong tài liệu thiết kế nếu có. -->

## Cách kiểm tra

<!-- Lệnh đã chạy, màn hình đã thử, ảnh chụp nếu đổi UI. -->

## Checklist

- [ ] Tiêu đề PR theo Conventional Commits (`feat(booking): ...`, `fix(auth): ...`)
- [ ] Đã chạy test liên quan (`./gradlew test`, `flutter test`)
- [ ] Đổi schema thì thêm migration Flyway mới, không sửa migration cũ
- [ ] Không commit secret (`.env`, keystore, token)
- [ ] Đã cập nhật README / Postman / tài liệu nếu đổi API hoặc cách chạy
