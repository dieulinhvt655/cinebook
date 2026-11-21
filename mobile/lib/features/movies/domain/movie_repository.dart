import 'movie.dart';

/// Throws `ApiFailure` on errors.
abstract interface class MovieRepository {
  /// Home tab, or a title search when [query] is given ([status] then optional).
  Future<List<MovieSummary>> movies({MovieStatus? status, String? query});

  Future<MovieDetail> detail(int id);
}
