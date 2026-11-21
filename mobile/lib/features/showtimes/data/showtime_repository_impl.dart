import '../../../core/network/api_guard.dart';
import '../../../core/utils/formatters.dart';
import '../domain/movie_showtimes.dart';
import '../domain/showtime_repository.dart';
import 'showtimes_api.dart';

class ShowtimeRepositoryImpl implements ShowtimeRepository {
  ShowtimeRepositoryImpl(this._api);

  final ShowtimesApi _api;

  @override
  Future<MovieShowtimes> forMovie(int movieId, DateTime date) => guardApi(
    () async => MovieShowtimes.fromJson(
      await _api.forMovie(movieId, formatIsoDate(date)),
    ),
  );
}
