import 'package:dio/dio.dart';

import '../session/auth_session.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// Base URL comes from `--dart-define=API_BASE_URL=...`.
/// Android emulator -> host machine is 10.0.2.2.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080/api/v1',
);

class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    required AuthSession session,
    String baseUrl = apiBaseUrl,
  }) : dio = Dio(_options(baseUrl)) {
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        refreshDio: Dio(_options(baseUrl)),
        tokenStorage: tokenStorage,
        session: session,
      ),
    );
  }

  final Dio dio;

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    // Render free tier sleeps; the first request can take 30-60 s to wake it up.
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 30),
    contentType: Headers.jsonContentType,
  );
}
