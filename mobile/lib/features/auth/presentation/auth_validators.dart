import 'dart:convert';

/// Form validators for S02/S03. They return the Vietnamese message to show, or null when valid.
/// Limits match the backend (`RegisterRequest`, `PasswordPolicy`) so most mistakes are caught
/// before a request is sent; the backend stays the source of truth (common-password check).
abstract final class AuthValidators {
  static const passwordMin = 15;
  static const passwordMax = 64;
  static const _passwordMaxBytes = 72;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phone = RegExp(r'^(0|\+84)\d{9}$');

  /// BR-01.2, BR-01.6, BR-04.1.
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập email';
    if (v.length > 254) return 'Email tối đa 254 ký tự';
    if (!_email.hasMatch(v)) return 'Email không đúng định dạng';
    return null;
  }

  /// Login only checks presence (BR-02 note): old accounts keep working.
  static String? loginPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Vui lòng nhập mật khẩu' : null;

  /// BR-02.1–02.3: counts characters (not bytes), never trims.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    final length = value.runes.length;
    if (length < passwordMin) {
      return 'Mật khẩu phải có ít nhất $passwordMin ký tự';
    }
    if (length > passwordMax || utf8.encode(value).length > _passwordMaxBytes) {
      return 'Mật khẩu quá dài (tối đa $passwordMax ký tự)';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập lại mật khẩu';
    return value == password ? null : 'Mật khẩu nhập lại không khớp';
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập họ tên';
    if (v.length > 150) return 'Họ tên tối đa 150 ký tự';
    return null;
  }

  /// Optional; Vietnamese mobile number when given.
  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return _phone.hasMatch(v) ? null : 'Số điện thoại không hợp lệ';
  }
}
