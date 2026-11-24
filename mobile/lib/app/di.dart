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
import '../features/movies/data/movie_repository_impl.dart';
import '../features/movies/data/movies_api.dart';
import '../features/movies/domain/movie_repository.dart';
import '../features/movies/presentation/recent_searches.dart';
import '../features/seat_map/data/seat_map_api.dart';
import '../features/seat_map/data/seat_map_repository_impl.dart';
import '../features/seat_map/domain/seat_map_repository.dart';
import '../features/showtimes/data/showtime_repository_impl.dart';
import '../features/showtimes/data/showtimes_api.dart';
import '../features/showtimes/domain/showtime_repository.dart';
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

  // Movies & showtimes
  sl
    ..registerLazySingleton<MoviesApi>(() => MoviesApi(sl<ApiClient>().dio))
    ..registerLazySingleton<MovieRepository>(() => MovieRepositoryImpl(sl()))
    ..registerLazySingleton<RecentSearches>(RecentSearches.new)
    ..registerLazySingleton<ShowtimesApi>(
      () => ShowtimesApi(sl<ApiClient>().dio),
    )
    ..registerLazySingleton<ShowtimeRepository>(
      () => ShowtimeRepositoryImpl(sl()),
    );

  // Seat map
  sl
    ..registerLazySingleton<SeatMapApi>(() => SeatMapApi(sl<ApiClient>().dio))
    ..registerLazySingleton<SeatMapRepository>(
      () => SeatMapRepositoryImpl(sl(), sl()),
    );

  // Other features register their data sources / repositories here:
  // checkout, tickets.
}
