import 'register_input.dart';
import 'user.dart';

/// Every method throws `ApiFailure` for errors the user should see.
abstract interface class AuthRepository {
  /// Signs in and stores the tokens; the router then leaves the auth screens.
  Future<User> login({required String email, required String password});

  /// Creates the account and signs straight in.
  Future<User> register(RegisterInput input);

  /// Splash (BR-07.2): checks the stored session with the server via `GET /me`, refreshing
  /// the access token if needed. Ends authenticated or unauthenticated; throws only when the
  /// server could not be reached, so a network problem never signs the user out.
  Future<void> restoreSession();

  Future<User> me();

  /// Revokes the session on the server (best effort) and always clears local tokens (BR-05.5).
  Future<void> logout();
}
