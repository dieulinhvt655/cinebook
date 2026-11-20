import 'package:dio/dio.dart';

import '../session/auth_session.dart';
import '../storage/token_storage.dart';

/// Adds `Authorization: Bearer` and transparently refreshes on 401.
///
/// It is a [QueuedInterceptor], so errors are handled one at a time: when many requests
/// fail with 401 together, only the first one calls /auth/refresh; the others see that the
/// stored token has changed and simply retry with it.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio dio,
    required Dio refreshDio,
    required TokenStorage tokenStorage,
    required AuthSession session,
  }) : _dio = dio,
       _refreshDio = refreshDio,
       _tokens = tokenStorage,
       _session = session;

  /// Set `extra: {AuthInterceptor.skipAuth: true}` on public calls such as login.
  static const skipAuth = 'skipAuth';
  static const _retried = 'authRetried';

  final Dio _dio;
  final Dio _refreshDio;
  final TokenStorage _tokens;
  final AuthSession _session;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuth] != true) {
      final token = await _tokens.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        req.extra[skipAuth] == true ||
        req.extra[_retried] == true) {
      return handler.next(err);
    }

    final sentToken = (req.headers['Authorization'] as String?)?.substring(7);
    var current = await _tokens.readAccessToken();

    // Another request already refreshed while this one was waiting in the queue.
    if (current == null || current == sentToken) {
      current = await _refresh();
      if (current == null) {
        await _tokens.clear();
        _session.expire();
        return handler.next(err);
      }
    }

    try {
      req.extra[_retried] = true;
      req.headers['Authorization'] = 'Bearer $current';
      handler.resolve(await _dio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Rotates the refresh token. Returns the new access token, or null if the session is over.
  Future<String?> _refresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return null;
    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final access = res.data!['accessToken'] as String;
      await _tokens.save(
        accessToken: access,
        refreshToken: res.data!['refreshToken'] as String,
      );
      return access;
    } on DioException {
      return null;
    }
  }
}
