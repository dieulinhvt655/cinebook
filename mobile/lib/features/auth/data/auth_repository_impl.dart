import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_repository.dart';
import '../domain/register_input.dart';
import '../domain/user.dart';
import 'auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi api,
    required TokenStorage tokens,
    required AuthSession session,
  }) : _api = api,
       _tokens = tokens,
       _session = session;

  final AuthApi _api;
  final TokenStorage _tokens;
  final AuthSession _session;

  @override
  Future<User> login({required String email, required String password}) =>
      _signIn(() => _api.login(email.trim(), password));

  @override
  Future<User> register(RegisterInput input) =>
      _signIn(() => _api.register(input.toJson()));

  @override
  Future<void> restoreSession() async {
    if (await _tokens.readRefreshToken() == null) {
      _session.expire();
      return;
    }
    try {
      // A 401 here is refreshed by AuthInterceptor; it only comes back if that failed too.
      await _api.me(wakeUp: true);
      _session.resume();
    } on DioException catch (e) {
      final failure = ApiFailure.fromDio(e);
      if (failure.status != 401) throw failure;
      await _session.signOut();
    }
  }

  @override
  Future<User> me() => _guard(() async => User.fromJson(await _api.me()));

  @override
  Future<void> logout() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } on DioException {
        // Offline or server down: the local session still ends; the token expires by itself.
      }
    }
    await _session.signOut();
  }

  Future<User> _signIn(Future<Map<String, dynamic>> Function() call) =>
      _guard(() async {
        final json = await call();
        await _session.signIn(
          accessToken: json['accessToken'] as String,
          refreshToken: json['refreshToken'] as String,
        );
        return User.fromJson(json['user'] as Map<String, dynamic>);
      });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }
}
