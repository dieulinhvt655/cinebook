import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/showtimes/domain/movie_showtimes.dart';
import 'package:cinebook/features/showtimes/domain/showtime_repository.dart';
import 'package:cinebook/features/showtimes/presentation/cubit/showtime_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../movies/catalog_fixtures.dart';

class _Repo extends Mock implements ShowtimeRepository {}

void main() {
  late _Repo repo;
  final today = DateTime.utc(2026, 11, 22);
  final hcm = cinema(1, 'Hồ Chí Minh', [slot(10)]);
  final hn = cinema(2, 'Hà Nội', [slot(20)]);

  MovieShowtimes day(DateTime d, List<CinemaShowtimes> c, [DateTime? next]) =>
      MovieShowtimes(movieId: 7, date: d, cinemas: c, nextAvailableDate: next);

  setUpAll(() => registerFallbackValue(DateTime.utc(2000)));
  setUp(() => repo = _Repo());

  ShowtimeCubit build() => ShowtimeCubit(repo, 7, today: today);

  test('day strip is today plus the next 6 days', () {
    final c = build();
    expect(c.state.days.first, today);
    expect(c.state.days.last, DateTime.utc(2026, 11, 28));
    expect(c.state.days, hasLength(7));
    expect(c.state.loading, isTrue);
  });

  blocTest<ShowtimeCubit, ShowtimeState>(
    'an empty day offers the next date; picking it beyond the strip adds a chip',
    setUp: () {
      when(
        () => repo.forMovie(7, today),
      ).thenAnswer((_) async => day(today, [], DateTime.utc(2026, 12, 2)));
      when(
        () => repo.forMovie(7, DateTime.utc(2026, 12, 2)),
      ).thenAnswer((_) async => day(DateTime.utc(2026, 12, 2), [hcm]));
    },
    build: build,
    act: (c) async {
      await c.load();
      expect(c.state.cinemas, isEmpty);
      await c.selectDate(c.state.data!.nextAvailableDate!);
    },
    verify: (c) {
      expect(c.state.date, DateTime.utc(2026, 12, 2));
      expect(c.state.days, hasLength(8));
      expect(c.state.days.last, DateTime.utc(2026, 12, 2));
      expect(c.state.cinemas, [hcm]);
    },
  );

  blocTest<ShowtimeCubit, ShowtimeState>(
    'the city filter keeps only that city and survives a day change',
    setUp: () => when(() => repo.forMovie(7, any())).thenAnswer(
      (i) async => day(i.positionalArguments[1] as DateTime, [hcm, hn]),
    ),
    build: build,
    act: (c) async {
      await c.load();
      c.selectCity('Hà Nội');
      await c.selectDate(DateTime.utc(2026, 11, 23));
    },
    verify: (c) {
      expect(c.state.cities, ['Hà Nội', 'Hồ Chí Minh']);
      expect(c.state.city, 'Hà Nội');
      expect(c.state.cinemas, [hn]);
    },
  );

  test('the answer for a day the user already left is dropped', () async {
    final slow = Completer<MovieShowtimes>();
    final tomorrow = DateTime.utc(2026, 11, 23);
    when(() => repo.forMovie(7, today)).thenAnswer((_) => slow.future);
    when(
      () => repo.forMovie(7, tomorrow),
    ).thenAnswer((_) async => day(tomorrow, [hn]));
    final c = build();
    final first = c.load();
    await c.selectDate(tomorrow);
    slow.complete(day(today, [hcm]));
    await first;
    expect(c.state.date, tomorrow);
    expect(c.state.cinemas, [hn]);
    await c.close();
  });

  blocTest<ShowtimeCubit, ShowtimeState>(
    'errors are shown in the list area, the strip stays',
    setUp: () => when(
      () => repo.forMovie(7, today),
    ).thenThrow(const ApiFailure(code: ApiFailure.offline, message: 'offline')),
    build: build,
    act: (c) => c.load(),
    verify: (c) {
      expect(c.state.failure?.code, ApiFailure.offline);
      expect(c.state.days, hasLength(7));
    },
  );
}
