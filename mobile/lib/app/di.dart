import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../core/network/api_client.dart';
import '../core/network/server_clock.dart';
import '../core/session/auth_session.dart';
import '../core/storage/app_preferences.dart';
import '../core/storage/token_storage.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/checkout/data/booking_repository_impl.dart';
import '../features/checkout/data/bookings_api.dart';
import '../features/checkout/domain/booking_repository.dart';
import '../features/movies/data/movie_repository_impl.dart';
import '../features/movies/data/movies_api.dart';
import '../features/movies/domain/movie_repository.dart';
import '../features/movies/presentation/recent_searches.dart';
import '../features/seat_map/data/seat_map_api.dart';
import '../features/seat_map/data/seat_map_repository_impl.dart';
import '../features/seat_map/domain/seat_map_repository.dart';
import '../features/showtimes/data/cinema_repository_impl.dart';
import '../features/showtimes/data/cinemas_api.dart';
import '../features/showtimes/data/showtime_repository_impl.dart';
import '../features/showtimes/data/showtimes_api.dart';
import '../features/showtimes/domain/cinema_repository.dart';
import '../features/showtimes/domain/showtime_repository.dart';
import '../features/showtimes/presentation/cubit/city_cubit.dart';
import '../features/tickets/data/ticket_repository_impl.dart';
import '../features/tickets/data/tickets_api.dart';
import '../features/tickets/domain/ticket_repository.dart';
import '../features/tickets/presentation/cubit/tickets_cubit.dart';
import 'router.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  // Core
  sl
    ..registerSingleton<AppPreferences>(AppPreferences(prefs))
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
    ..registerLazySingleton<RecentSearches>(() => RecentSearches(sl()))
    ..registerLazySingleton<ShowtimesApi>(
      () => ShowtimesApi(sl<ApiClient>().dio),
    )
    ..registerLazySingleton<ShowtimeRepository>(
      () => ShowtimeRepositoryImpl(sl()),
    )
    ..registerLazySingleton<CinemasApi>(() => CinemasApi(sl<ApiClient>().dio))
    ..registerLazySingleton<CinemaRepository>(() => CinemaRepositoryImpl(sl()))
    // App-wide: the city picked on Home also drives S07 and the "Rạp" tab.
    ..registerLazySingleton<CityCubit>(() => CityCubit(sl(), sl()));

  // Seat map
  sl
    ..registerLazySingleton<SeatMapApi>(() => SeatMapApi(sl<ApiClient>().dio))
    ..registerLazySingleton<SeatMapRepository>(
      () => SeatMapRepositoryImpl(sl(), sl()),
    );

  // Bookings (seat hold, checkout)
  sl
    ..registerLazySingleton<BookingsApi>(() => BookingsApi(sl<ApiClient>().dio))
    ..registerLazySingleton<BookingRepository>(
      () => BookingRepositoryImpl(sl(), sl()),
    );

  // Tickets (F7). App-wide so a new payment can refresh the list.
  sl
    ..registerLazySingleton<TicketsApi>(() => TicketsApi(sl<ApiClient>().dio))
    ..registerLazySingleton<TicketRepository>(() => TicketRepositoryImpl(sl()))
    ..registerLazySingleton<TicketsCubit>(() => TicketsCubit(sl()));

  // Recent searches and tickets belong to the person signed in: forget them on sign-out.
  final session = sl<AuthSession>();
  session.addListener(() {
    if (session.status == AuthStatus.unauthenticated) {
      sl<RecentSearches>().clear();
      sl<TicketsCubit>().clear();
    }
  });
}
