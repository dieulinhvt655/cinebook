import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/movies/domain/movie_repository.dart';
import 'package:cinebook/features/movies/presentation/cubit/search_cubit.dart';
import 'package:cinebook/features/movies/presentation/recent_searches.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog_fixtures.dart';

class _Repo extends Mock implements MovieRepository {}

void main() {
  late _Repo repo;
  late RecentSearches recent;
  const wait = Duration(milliseconds: 20);

  setUp(() {
    repo = _Repo();
    recent = RecentSearches();
  });

  SearchCubit build() => SearchCubit(repo, recent, debounce: wait);

  blocTest<SearchCubit, SearchState>(
    'typing fast sends one request, for the last text',
    setUp: () => when(
      () => repo.movies(query: any(named: 'query')),
    ).thenAnswer((_) async => [movie(1)]),
    build: build,
    act: (c) async {
      c
        ..changed('a')
        ..changed('av')
        ..changed('avengers ');
      await Future<void>.delayed(wait * 3);
    },
    verify: (c) {
      verify(() => repo.movies(query: 'avengers')).called(1);
      verifyNoMoreInteractions(repo);
      expect(c.state.query, 'avengers');
      expect(c.state.results, [movie(1)]);
    },
  );

  blocTest<SearchCubit, SearchState>(
    'no results gives an empty list (empty state), not null',
    setUp: () => when(
      () => repo.movies(query: any(named: 'query')),
    ).thenAnswer((_) async => []),
    build: build,
    act: (c) => c.submit('xyz'),
    verify: (c) {
      expect(c.state.results, isEmpty);
      expect(c.state.query, 'xyz');
    },
  );

  test('an older answer arriving late is dropped', () async {
    final slow = Completer<List<dynamic>>();
    when(
      () => repo.movies(query: 'old'),
    ).thenAnswer((_) async => (await slow.future).cast());
    when(() => repo.movies(query: 'new')).thenAnswer((_) async => [movie(2)]);
    final c = build();
    final first = c.submit('old');
    await c.submit('new');
    slow.complete([movie(1)]);
    await first;
    expect(c.state.query, 'new');
    expect(c.state.results, [movie(2)]);
    await c.close();
  });

  blocTest<SearchCubit, SearchState>(
    'an error keeps the previous results',
    build: build,
    seed: () => SearchState(query: 'a', results: [movie(1)]),
    setUp: () => when(
      () => repo.movies(query: 'b'),
    ).thenThrow(const ApiFailure(code: ApiFailure.offline, message: 'offline')),
    act: (c) => c.submit('b'),
    verify: (c) {
      expect(c.state.results, [movie(1)]);
      expect(c.state.failure?.code, ApiFailure.offline);
      expect(c.state.loading, isFalse);
    },
  );

  blocTest<SearchCubit, SearchState>(
    'submitted searches go to the recent list, newest first, no duplicates',
    setUp: () => when(
      () => repo.movies(query: any(named: 'query')),
    ).thenAnswer((_) async => []),
    build: build,
    act: (c) async {
      await c.submit('Avengers');
      await c.submit('Nhà bà');
      await c.submit('avengers');
      c.changed('');
    },
    verify: (c) {
      expect(c.state.results, isNull);
      expect(c.state.recent, ['avengers', 'Nhà bà']);
    },
  );

  test('recent list keeps the last ${RecentSearches.max}', () {
    for (var i = 0; i < 8; i++) {
      recent.add('q$i');
    }
    expect(recent.items, ['q7', 'q6', 'q5', 'q4', 'q3']);
  });
}
