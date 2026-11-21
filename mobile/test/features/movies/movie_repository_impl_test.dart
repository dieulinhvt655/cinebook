import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/movies/data/movie_repository_impl.dart';
import 'package:cinebook/features/movies/data/movies_api.dart';
import 'package:cinebook/features/movies/domain/movie.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog_fixtures.dart';

class _Api extends Mock implements MoviesApi {}

void main() {
  late _Api api;
  late MovieRepositoryImpl repo;
  final req = RequestOptions(path: '/movies');

  setUp(() {
    api = _Api();
    repo = MovieRepositoryImpl(api);
  });

  test('sends the tab as the API status value', () async {
    when(
      () => api.list(status: 'COMING_SOON'),
    ).thenAnswer((_) async => [movieJson]);
    final list = await repo.movies(status: MovieStatus.comingSoon);
    expect(list.single.title, 'Avengers of the Abyss');
  });

  test('a 404 problem becomes an ApiFailure with its code', () async {
    when(() => api.detail(99)).thenThrow(
      DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: req,
          statusCode: 404,
          data: {'code': 'NOT_FOUND', 'detail': 'Không tìm thấy phim'},
        ),
      ),
    );
    expect(
      () => repo.detail(99),
      throwsA(
        isA<ApiFailure>()
            .having((f) => f.code, 'code', 'NOT_FOUND')
            .having((f) => f.status, 'status', 404),
      ),
    );
  });
}
