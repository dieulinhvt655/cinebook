import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/movies/domain/movie.dart';
import 'package:cinebook/features/movies/domain/movie_repository.dart';
import 'package:cinebook/features/movies/presentation/cubit/movie_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog_fixtures.dart';

class _Repo extends Mock implements MovieRepository {}

void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());

  final detail = MovieDetail.fromJson({
    ...movieJson,
    'description': 'Mô tả',
    'endDate': null,
    'language': 'Tiếng Anh',
    'trailerUrl': null,
  });

  blocTest<MovieDetailCubit, MovieDetailState>(
    'loads the movie',
    setUp: () => when(() => repo.detail(7)).thenAnswer((_) async => detail),
    build: () => MovieDetailCubit(repo, 7),
    act: (c) => c.load(),
    expect: () => [const MovieDetailState(), MovieDetailState(movie: detail)],
  );

  blocTest<MovieDetailCubit, MovieDetailState>(
    'a missing or hidden movie says it is no longer showing',
    setUp: () => when(() => repo.detail(7)).thenThrow(
      const ApiFailure(
        code: 'NOT_FOUND',
        message: 'Không tìm thấy phim',
        status: 404,
      ),
    ),
    build: () => MovieDetailCubit(repo, 7),
    act: (c) => c.load(),
    verify: (c) =>
        expect(c.state.failure?.message, MovieDetailCubit.notShowing),
  );
}
