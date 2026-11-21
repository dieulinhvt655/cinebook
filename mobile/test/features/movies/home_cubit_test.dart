import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/movies/domain/movie.dart';
import 'package:cinebook/features/movies/domain/movie_repository.dart';
import 'package:cinebook/features/movies/presentation/cubit/home_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog_fixtures.dart';

class _Repo extends Mock implements MovieRepository {}

void main() {
  late _Repo repo;
  final now = [movie(1), movie(2)];
  final soon = [movie(3)];
  const offline = ApiFailure(code: ApiFailure.offline, message: 'offline');

  setUp(() => repo = _Repo());

  void answer() {
    when(
      () => repo.movies(status: MovieStatus.nowShowing),
    ).thenAnswer((_) async => now);
    when(
      () => repo.movies(status: MovieStatus.comingSoon),
    ).thenAnswer((_) async => soon);
  }

  blocTest<HomeCubit, HomeState>(
    'loads both tabs, then switching tabs needs no request',
    setUp: answer,
    build: () => HomeCubit(repo),
    act: (c) async {
      await c.load();
      c.selectTab(MovieStatus.comingSoon);
    },
    expect: () => [
      const HomeState(loading: true),
      HomeState(nowShowing: now, comingSoon: soon),
      HomeState(tab: MovieStatus.comingSoon, nowShowing: now, comingSoon: soon),
    ],
    verify: (c) {
      expect(c.state.visible, soon);
      expect(c.state.banners, now);
      verify(() => repo.movies(status: MovieStatus.nowShowing)).called(1);
    },
  );

  blocTest<HomeCubit, HomeState>(
    'a failed refresh keeps the movies already shown',
    build: () => HomeCubit(repo),
    seed: () => HomeState(nowShowing: now, comingSoon: soon),
    setUp: () => when(
      () => repo.movies(status: any(named: 'status')),
    ).thenThrow(offline),
    act: (c) => c.load(),
    expect: () => [
      HomeState(nowShowing: now, comingSoon: soon, loading: true),
      HomeState(nowShowing: now, comingSoon: soon, failure: offline),
    ],
  );

  blocTest<HomeCubit, HomeState>(
    'first load failing leaves no data (ErrorView with retry)',
    build: () => HomeCubit(repo),
    setUp: () => when(
      () => repo.movies(status: any(named: 'status')),
    ).thenThrow(offline),
    act: (c) => c.load(),
    verify: (c) {
      expect(c.state.hasData, isFalse);
      expect(c.state.failure, offline);
    },
  );
}
