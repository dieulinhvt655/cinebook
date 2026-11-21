import '../../../core/network/api_guard.dart';
import '../domain/movie.dart';
import '../domain/movie_repository.dart';
import 'movies_api.dart';

class MovieRepositoryImpl implements MovieRepository {
  MovieRepositoryImpl(this._api);

  final MoviesApi _api;

  @override
  Future<List<MovieSummary>> movies({MovieStatus? status, String? query}) =>
      guardApi(() async {
        final json = await _api.list(status: status?.apiValue, query: query);
        return json
            .map((e) => MovieSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<MovieDetail> detail(int id) =>
      guardApi(() async => MovieDetail.fromJson(await _api.detail(id)));
}
