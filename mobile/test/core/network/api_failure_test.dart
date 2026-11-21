import 'package:cinebook/core/network/api_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final req = RequestOptions(path: '/auth/login');

  DioException http(int status, Object? body) => DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: req,
      statusCode: status,
      data: body,
    ),
  );

  test('uses the backend ProblemDetail message and code', () {
    final f = ApiFailure.fromDio(
      http(401, {
        'code': 'INVALID_CREDENTIALS',
        'detail': 'Email hoặc mật khẩu không chính xác',
        'status': 401,
      }),
    );
    expect(f.code, 'INVALID_CREDENTIALS');
    expect(f.message, 'Email hoặc mật khẩu không chính xác');
    expect(f.status, 401);
    expect(f.isConnectivity, isFalse);
  });

  test('keeps per-field validation messages', () {
    final f = ApiFailure.fromDio(
      http(400, {
        'code': 'VALIDATION_FAILED',
        'detail': 'Dữ liệu không hợp lệ',
        'fields': {'password': 'Mật khẩu quá phổ biến'},
      }),
    );
    expect(f.fields, {'password': 'Mật khẩu quá phổ biến'});
  });

  test('5xx never shows the server body (BR-04.5)', () {
    final f = ApiFailure.fromDio(
      http(500, {
        'code': 'INTERNAL_ERROR',
        'detail': 'NullPointerException at ...',
      }),
    );
    expect(f.code, ApiFailure.server);
    expect(f.message, 'Hệ thống đang gặp sự cố, vui lòng thử lại sau');
  });

  test(
    'no connection vs timeout get different messages (BR-04.3, BR-04.4)',
    () {
      final offline = ApiFailure.fromDio(
        DioException(
          requestOptions: req,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(offline.code, ApiFailure.offline);
      expect(offline.isConnectivity, isTrue);

      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final f = ApiFailure.fromDio(
          DioException(requestOptions: req, type: type),
        );
        expect(f.code, ApiFailure.timeout, reason: '$type');
        expect(f.message, 'Kết nối quá thời gian chờ, vui lòng thử lại');
      }
    },
  );
}
