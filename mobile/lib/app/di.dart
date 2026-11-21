import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../core/network/api_client.dart';
import '../core/network/server_clock.dart';
import '../core/session/auth_session.dart';
import '../core/storage/token_storage.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/auth_repository.dart';
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

  // Auth
  sl
    ..registerLazySingleton<AuthApi>(() => AuthApi(sl<ApiClient>().dio))
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(api: sl(), tokens: sl(), session: sl()),
    );

  // Other features register their data sources / repositories here:
  // movies, showtimes, seat_map, checkout, tickets.
}
