import 'movie.dart';

/// Throws `ApiFailure` on errors.
abstract interface class MovieRepository {
  /// Home tab, or a title search when [query] is given ([status] then optional).
  /// [city] narrows "now showing" to showtimes in that city.
  Future<List<MovieSummary>> movies({
    MovieStatus? status,
    String? query,
    String? city,
  });

  Future<MovieDetail> detail(int id);
}
