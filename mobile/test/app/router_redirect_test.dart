import 'package:cinebook/app/router.dart';
import 'package:cinebook/core/session/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? go(AuthStatus s, String location) =>
      authRedirect(s, Uri.parse(location));

  group('unknown session', () {
    test('everything waits on splash', () {
      expect(go(AuthStatus.unknown, '/'), Routes.splash);
      expect(go(AuthStatus.unknown, Routes.splash), isNull);
    });
  });

  group('signed out', () {
    test('protected screens go to login with redirect back', () {
      expect(
        go(AuthStatus.unauthenticated, '/showtimes/7/seats'),
        '/login?redirect=%2Fshowtimes%2F7%2Fseats',
      );
    });

    test('login and register stay reachable; splash moves on to login', () {
      expect(go(AuthStatus.unauthenticated, Routes.login), isNull);
      expect(go(AuthStatus.unauthenticated, Routes.register), isNull);
      expect(go(AuthStatus.unauthenticated, Routes.splash), Routes.login);
    });
  });

  group('signed in', () {
    test('auth screens bounce to home or the redirect target', () {
      expect(go(AuthStatus.authenticated, Routes.login), Routes.home);
      expect(
        go(
          AuthStatus.authenticated,
          '/login?redirect=%2Fshowtimes%2F7%2Fseats',
        ),
        '/showtimes/7/seats',
      );
    });

    test('protected screens are allowed', () {
      expect(go(AuthStatus.authenticated, '/tickets'), isNull);
    });
  });
}
