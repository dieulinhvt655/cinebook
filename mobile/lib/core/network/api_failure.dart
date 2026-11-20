import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// Error shown to the user. Built from the backend ProblemDetail (RFC 9457):
/// `{ "code": "SEAT_TAKEN", "detail": "...", "status": 409 }`.
class ApiFailure extends Equatable implements Exception {
  const ApiFailure({required this.code, required this.message, this.status});

  factory ApiFailure.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['code'] is String) {
      return ApiFailure(
        code: data['code'] as String,
        message: (data['detail'] as String?) ?? _generic,
        status: e.response?.statusCode,
      );
    }
    return switch (e.type) {
      DioExceptionType.connectionError || DioExceptionType.connectionTimeout =>
        const ApiFailure(code: offline, message: 'Không có kết nối mạng'),
      DioExceptionType.receiveTimeout => const ApiFailure(
        code: timeout,
        message: 'Máy chủ phản hồi chậm, vui lòng thử lại',
      ),
      _ => ApiFailure(
        code: unknown,
        message: _generic,
        status: e.response?.statusCode,
      ),
    };
  }

  static const offline = 'OFFLINE';
  static const timeout = 'TIMEOUT';
  static const unknown = 'UNKNOWN';
  static const _generic = 'Đã có lỗi xảy ra, vui lòng thử lại';

  /// Backend `ErrorCode` value, e.g. SEAT_TAKEN, HOLD_EXPIRED.
  final String code;

  /// Vietnamese, user-facing; never a technical error code.
  final String message;
  final int? status;

  @override
  List<Object?> get props => [code, message, status];
}
