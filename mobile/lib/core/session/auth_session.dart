import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-wide login state. go_router listens to it to redirect (no guest mode:
/// without a session only Splash, Login and Register are reachable).
class AuthSession extends ChangeNotifier {
  AuthSession(this._tokens);

  final TokenStorage _tokens;
  AuthStatus _status = AuthStatus.unknown;

  AuthStatus get status => _status;

  /// Called by Splash: a stored refresh token means we can resume the session.
  Future<void> restore() async {
    final refresh = await _tokens.readRefreshToken();
    _set(
      refresh == null ? AuthStatus.unauthenticated : AuthStatus.authenticated,
    );
  }

  Future<void> signIn({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _tokens.save(accessToken: accessToken, refreshToken: refreshToken);
    _set(AuthStatus.authenticated);
  }

  Future<void> signOut() async {
    await _tokens.clear();
    _set(AuthStatus.unauthenticated);
  }

  /// Refresh token expired or revoked.
  void expire() => _set(AuthStatus.unauthenticated);

  void _set(AuthStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }
}
