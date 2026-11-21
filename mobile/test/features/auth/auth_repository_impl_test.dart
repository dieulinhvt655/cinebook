import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/core/session/auth_session.dart';
import 'package:cinebook/core/storage/token_storage.dart';
import 'package:cinebook/features/auth/data/auth_api.dart';
import 'package:cinebook/features/auth/data/auth_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements AuthApi {}

class _Tokens extends Mock implements TokenStorage {}

void main() {
  late _Api api;
  late _Tokens tokens;
  late AuthSession session;
  late AuthRepositoryImpl repo;

  final req = RequestOptions(path: '/');
  const userJson = {
    'id': 1,
    'email': 'demo@cinebook.dev',
    'fullName': 'Demo',
    'phone': null,
    'dateOfBirth': '2000-01-31',
    'role': 'CUSTOMER',
  };

  DioException status(int code) => DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(requestOptions: req, statusCode: code),
  );

  setUp(() {
    api = _Api();
    tokens = _Tokens();
    session = AuthSession(tokens);
    repo = AuthRepositoryImpl(api: api, tokens: tokens, session: session);
    when(
      () => tokens.save(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
    when(() => tokens.clear()).thenAnswer((_) async {});
  });

  group('login', () {
    test('stores both tokens and marks the session authenticated', () async {
      when(() => api.login('demo@cinebook.dev', 'pw')).thenAnswer(
        (_) async => {
          'accessToken': 'a',
          'refreshToken': 'r',
          'tokenType': 'Bearer',
          'expiresIn': 900,
          'user': userJson,
        },
      );

      final user = await repo.login(
        email: ' demo@cinebook.dev ',
        password: 'pw',
      );

      expect(user.email, 'demo@cinebook.dev');
      expect(user.dateOfBirth, DateTime(2000, 1, 31));
      verify(() => tokens.save(accessToken: 'a', refreshToken: 'r')).called(1);
      expect(session.status, AuthStatus.authenticated);
    });

    test('a rejected login throws ApiFailure and stores nothing', () async {
      when(() => api.login(any(), any())).thenThrow(status(401));

      await expectLater(
        repo.login(email: 'x@y.vn', password: 'pw'),
        throwsA(isA<ApiFailure>().having((f) => f.status, 'status', 401)),
      );
      verifyNever(
        () => tokens.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
      expect(session.status, AuthStatus.unknown);
    });
  });

  group('restoreSession (Splash)', () {
    test('no stored token: signed out without calling the server', () async {
      when(() => tokens.readRefreshToken()).thenAnswer((_) async => null);

      await repo.restoreSession();

      expect(session.status, AuthStatus.unauthenticated);
      verifyNever(() => api.me(wakeUp: any(named: 'wakeUp')));
    });

    test('server accepts the session: authenticated', () async {
      when(() => tokens.readRefreshToken()).thenAnswer((_) async => 'r');
      when(() => api.me(wakeUp: true)).thenAnswer((_) async => userJson);

      await repo.restoreSession();

      expect(session.status, AuthStatus.authenticated);
    });

    test(
      'session revoked or expired (401 after refresh): tokens cleared',
      () async {
        when(() => tokens.readRefreshToken()).thenAnswer((_) async => 'r');
        when(() => api.me(wakeUp: true)).thenThrow(status(401));

        await repo.restoreSession();

        expect(session.status, AuthStatus.unauthenticated);
        verify(() => tokens.clear()).called(1);
      },
    );

    test(
      'offline: throws and keeps the tokens so the user can retry',
      () async {
        when(() => tokens.readRefreshToken()).thenAnswer((_) async => 'r');
        when(() => api.me(wakeUp: true)).thenThrow(
          DioException(
            requestOptions: req,
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          repo.restoreSession(),
          throwsA(
            isA<ApiFailure>().having((f) => f.code, 'code', ApiFailure.offline),
          ),
        );
        verifyNever(() => tokens.clear());
        expect(session.status, AuthStatus.unknown);
      },
    );
  });

  group('logout (BR-05.5)', () {
    test('revokes on the server and clears local tokens', () async {
      when(() => tokens.readRefreshToken()).thenAnswer((_) async => 'r');
      when(() => api.logout('r')).thenAnswer((_) async {});

      await repo.logout();

      verify(() => api.logout('r')).called(1);
      verify(() => tokens.clear()).called(1);
      expect(session.status, AuthStatus.unauthenticated);
    });

    test(
      'still clears local tokens when the server cannot be reached',
      () async {
        when(() => tokens.readRefreshToken()).thenAnswer((_) async => 'r');
        when(() => api.logout('r')).thenThrow(
          DioException(
            requestOptions: req,
            type: DioExceptionType.connectionError,
          ),
        );

        await repo.logout();

        verify(() => tokens.clear()).called(1);
        expect(session.status, AuthStatus.unauthenticated);
      },
    );
  });
}
