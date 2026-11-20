import 'package:go_router/go_router.dart';

import '../core/session/auth_session.dart';
import '../features/auth/presentation/account_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/checkout/presentation/checkout_page.dart';
import '../features/checkout/presentation/combo_page.dart';
import '../features/checkout/presentation/payment_result_page.dart';
import '../features/movies/presentation/home_page.dart';
import '../features/movies/presentation/movie_detail_page.dart';
import '../features/movies/presentation/search_page.dart';
import '../features/seat_map/presentation/seat_map_page.dart';
import '../features/showtimes/presentation/cinemas_page.dart';
import '../features/showtimes/presentation/showtime_picker_page.dart';
import '../features/tickets/presentation/ticket_detail_page.dart';
import '../features/tickets/presentation/tickets_page.dart';
import 'home_shell.dart';

/// Paths of screens S01–S14 (design doc 4.1).
abstract final class Routes {
  static const splash = '/splash'; // S01
  static const login = '/login'; // S02
  static const register = '/register'; // S03
  static const home = '/'; // S04
  static const search = '/search'; // S05
  static const cinemas = '/cinemas';
  static const tickets = '/tickets'; // S12
  static const account = '/account'; // S14

  static String movie(int id) => '/movies/$id'; // S06
  static String showtimes(int movieId) => '/movies/$movieId/showtimes'; // S07
  static String seatMap(int showtimeId) =>
      '/showtimes/$showtimeId/seats'; // S08
  static String combos(int bookingId) => '/bookings/$bookingId/combos'; // S09
  static String checkout(int bookingId) =>
      '/bookings/$bookingId/checkout'; // S10
  static String result(int bookingId) => '/bookings/$bookingId/result'; // S11
  static String ticket(int id) => '/tickets/$id'; // S13

  static const public = {splash, login, register};
}

int _id(GoRouterState s, [String name = 'id']) =>
    int.parse(s.pathParameters[name]!);

/// No guest mode: without a session everything except Splash/Login/Register redirects to
/// Login, carrying `?redirect=` so the user returns to where they were (e.g. the seat map).
String? authRedirect(AuthStatus status, Uri uri) {
  final path = uri.path;
  final isPublic = Routes.public.contains(path);

  if (status == AuthStatus.unknown) {
    return path == Routes.splash ? null : Routes.splash;
  }
  if (status == AuthStatus.unauthenticated) {
    if (isPublic && path != Routes.splash) return null;
    if (path == Routes.splash) return Routes.login;
    return Uri(
      path: Routes.login,
      queryParameters: {'redirect': uri.toString()},
    ).toString();
  }
  // Authenticated.
  if (isPublic) return uri.queryParameters['redirect'] ?? Routes.home;
  return null;
}

GoRouter buildRouter(AuthSession session) => GoRouter(
  initialLocation: Routes.splash,
  refreshListenable: session,
  redirect: (_, state) => authRedirect(session.status, state.uri),
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
    GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
    GoRoute(path: Routes.register, builder: (_, _) => const RegisterPage()),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.cinemas,
              builder: (_, _) => const CinemasPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.tickets,
              builder: (_, _) => const TicketsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.account,
              builder: (_, _) => const AccountPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: Routes.search, builder: (_, _) => const SearchPage()),
    GoRoute(
      path: '/movies/:id',
      builder: (_, s) => MovieDetailPage(movieId: _id(s)),
      routes: [
        GoRoute(
          path: 'showtimes',
          builder: (_, s) => ShowtimePickerPage(movieId: _id(s)),
        ),
      ],
    ),
    GoRoute(
      path: '/showtimes/:id/seats',
      builder: (_, s) => SeatMapPage(showtimeId: _id(s)),
    ),
    GoRoute(
      path: '/bookings/:id/combos',
      builder: (_, s) => ComboPage(bookingId: _id(s)),
    ),
    GoRoute(
      path: '/bookings/:id/checkout',
      builder: (_, s) => CheckoutPage(bookingId: _id(s)),
    ),
    GoRoute(
      path: '/bookings/:id/result',
      builder: (_, s) => PaymentResultPage(bookingId: _id(s)),
    ),
    GoRoute(
      path: '/tickets/:id',
      builder: (_, s) => TicketDetailPage(ticketId: _id(s)),
    ),
  ],
);
