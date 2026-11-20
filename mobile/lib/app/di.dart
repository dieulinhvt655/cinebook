import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../core/network/api_client.dart';
import '../core/network/server_clock.dart';
import '../core/session/auth_session.dart';
import '../core/storage/token_storage.dart';
import 'router.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies() async {
  // Core
  sl
    ..registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    )
    ..registerLazySingleton<TokenStorage>(() => TokenStorage(sl()))
    ..registerLazySingleton<ServerClock>(ServerClock.new)
    ..registerLazySingleton<AuthSession>(() => AuthSession(sl()))
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(tokenStorage: sl(), session: sl()),
    )
    ..registerLazySingleton<GoRouter>(() => buildRouter(sl()));

  // Features register their data sources / repositories / blocs here:
  // auth, movies, showtimes, seat_map, checkout, tickets.
}
