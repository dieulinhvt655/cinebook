import 'cinema.dart';

/// Throws `ApiFailure` on errors.
abstract interface class CinemaRepository {
  Future<List<City>> cities();

  /// All cinemas, or those of [city].
  Future<List<Cinema>> cinemas({String? city});

  Future<CinemaSchedule> schedule(int cinemaId, DateTime date);
}
