import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// Error shown to the user. Built from the backend ProblemDetail (RFC 9457):
/// `{ "code": "SEAT_TAKEN", "detail": "...", "status": 409 }`; validation errors also carry
/// `fields: { "email": "..." }`.
class ApiFailure extends Equatable implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    this.status,
    this.fields = const {},
  });

  factory ApiFailure.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    // 5xx bodies are never shown: no stack traces or internal details (BR-04.5).
    if (status != null && status >= 500) {
      return ApiFailure(code: server, message: _serverError, status: status);
    }
    if (data is Map && data['code'] is String) {
      final fields = data['fields'];
      return ApiFailure(
        code: data['code'] as String,
        message: (data['detail'] as String?) ?? _generic,
        status: status,
        fields: fields is Map
            ? fields.map((k, v) => MapEntry(k.toString(), v.toString()))
            : const {},
      );
    }
    return switch (e.type) {
      DioExceptionType.connectionError => const ApiFailure(
        code: offline,
        message: 'Không có kết nối mạng, vui lòng kiểm tra và thử lại',
      ),
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiFailure(
        code: timeout,
        message: 'Kết nối quá thời gian chờ, vui lòng thử lại',
      ),
      _ => ApiFailure(code: unknown, message: _generic, status: status),
    };
  }

  static const offline = 'OFFLINE';
  static const timeout = 'TIMEOUT';
  static const server = 'SERVER_ERROR';
  static const unknown = 'UNKNOWN';
  static const _generic = 'Đã có lỗi xảy ra, vui lòng thử lại';
  static const _serverError = 'Hệ thống đang gặp sự cố, vui lòng thử lại sau';

  /// Backend `ErrorCode` value, e.g. SEAT_TAKEN, HOLD_EXPIRED.
  final String code;

  /// Vietnamese, user-facing; never a technical error code.
  final String message;
  final int? status;

  /// Per-field validation messages (code VALIDATION_FAILED), keyed by request field name.
  final Map<String, String> fields;

  /// Network problem rather than a server answer: worth a "Thử lại" button.
  bool get isConnectivity => code == offline || code == timeout;

  @override
  List<Object?> get props => [code, message, status, fields];
}
