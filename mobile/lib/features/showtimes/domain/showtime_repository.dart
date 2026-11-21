import 'movie_showtimes.dart';

/// Throws `ApiFailure` on errors.
abstract interface class ShowtimeRepository {
  /// Showtimes of [movieId] on the Vietnam calendar day [date].
  Future<MovieShowtimes> forMovie(int movieId, DateTime date);
}
