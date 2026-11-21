import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/auth_interceptor.dart';

/// Raw calls to the auth endpoints; responses come back as JSON maps.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// Login, register and logout carry no access token, and a 401 from them is never refreshed.
  static final _public = Options(extra: {AuthInterceptor.skipAuth: true});

  /// Splash only: gives the sleeping free-tier server time to start.
  static final _wakeUp = Options(
    connectTimeout: ApiClient.wakeUpTimeout,
    sendTimeout: ApiClient.wakeUpTimeout,
    receiveTimeout: ApiClient.wakeUpTimeout,
  );

  Future<Map<String, dynamic>> login(String email, String password) async =>
      (await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
        options: _public,
      )).data!;

  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async =>
      (await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: body,
        options: _public,
      )).data!;

  Future<void> logout(String refreshToken) => _dio.post<void>(
    '/auth/logout',
    data: {'refreshToken': refreshToken},
    options: _public,
  );

  Future<Map<String, dynamic>> me({bool wakeUp = false}) async =>
      (await _dio.get<Map<String, dynamic>>(
        '/me',
        options: wakeUp ? _wakeUp : null,
      )).data!;
}
