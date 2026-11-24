import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/core/storage/app_preferences.dart';
import 'package:cinebook/features/movies/domain/movie.dart';
import 'package:cinebook/features/movies/domain/movie_repository.dart';
import 'package:cinebook/features/movies/presentation/cubit/home_cubit.dart';
import 'package:cinebook/features/movies/presentation/recent_searches.dart';
import 'package:cinebook/features/showtimes/domain/cinema.dart';
import 'package:cinebook/features/showtimes/domain/cinema_repository.dart';
import 'package:cinebook/features/showtimes/presentation/cubit/cinema_schedule_cubit.dart';
import 'package:cinebook/features/showtimes/presentation/cubit/cinemas_cubit.dart';
import 'package:cinebook/features/showtimes/presentation/cubit/city_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../movies/catalog_fixtures.dart';

class _Cinemas extends Mock implements CinemaRepository {}

class _Movies extends Mock implements MovieRepository {}

const hanoi = City(name: 'Hà Nội', cinemaCount: 2);
const hcm = City(name: 'TP. Hồ Chí Minh', cinemaCount: 1);
const trangTien = Cinema(
  id: 1,
  name: 'CineBook Tràng Tiền',
  city: 'Hà Nội',
  address: '1 Tràng Tiền',
);

Future<AppPreferences> prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return AppPreferences(await SharedPreferences.getInstance());
}

void main() {
  late _Cinemas repo;
  setUpAll(() => registerFallbackValue(DateTime.utc(2000)));
  setUp(() => repo = _Cinemas());

  test('schedule JSON parses cinema, movies and next date', () {
    final s = CinemaSchedule.fromJson({
      'cinema': {
        'id': 1,
        'name': 'CineBook Tràng Tiền',
        'city': 'Hà Nội',
        'address': '1 Tràng Tiền',
        'phone': null,
      },
      'date': '2026-11-25',
      'movies': [
        {
          'movieId': 7,
          'title': 'Chợ Đêm',
          'posterUrl': '/media/posters/cho-dem.jpg',
          'ageRating': 'T16',
          'durationMin': 116,
          'showtimes': [
            {
              'id': 10,
              'startAt': '2026-11-25T02:00:00Z',
              'endAt': '2026-11-25T04:00:00Z',
              'format': '2D',
              'subtitle': 'SUB',
              'auditorium': 'Phòng 1',
              'basePrice': 80000,
              'bookable': true,
              'availableSeats': 120,
            },
          ],
        },
      ],
      'nextAvailableDate': null,
    });
    expect(s.cinema, trangTien);
    expect(s.date, DateTime.utc(2026, 11, 25));
    expect(s.movies.single.posterUrl, '/media/posters/cho-dem.jpg');
    expect(s.movies.single.showtimes.single.availableSeats, 120);
  });

  group('CityCubit', () {
    test(
      'keeps a saved city that still has cinemas and persists a new pick',
      () async {
        final p = await prefs({'city': 'Hà Nội'});
        when(() => repo.cities()).thenAnswer((_) async => [hanoi, hcm]);
        final c = CityCubit(repo, p);
        expect(c.state.selected, 'Hà Nội');
        await c.load();
        expect(c.state.cities, [hanoi, hcm]);
        expect(c.state.selected, 'Hà Nội');

        await c.select('TP. Hồ Chí Minh');
        expect(p.city, 'TP. Hồ Chí Minh');
        await c.select(null);
        expect(p.city, isNull);
      },
    );

    test('a saved city without cinemas falls back to every city', () async {
      final p = await prefs({'city': 'Đà Nẵng'});
      when(() => repo.cities()).thenAnswer((_) async => [hanoi]);
      final c = CityCubit(repo, p);
      await c.load();
      expect(c.state.selected, isNull);
      expect(p.city, isNull);
    });

    test('a failed load keeps the saved choice', () async {
      final p = await prefs({'city': 'Hà Nội'});
      when(() => repo.cities()).thenThrow(
        const ApiFailure(code: ApiFailure.offline, message: 'offline'),
      );
      final c = CityCubit(repo, p);
      await c.load();
      expect(c.state.selected, 'Hà Nội');
    });
  });

  blocTest<CinemasCubit, CinemasState>(
    'cinemas follow the picked city',
    setUp: () {
      when(
        () => repo.cinemas(city: 'Hà Nội'),
      ).thenAnswer((_) async => [trangTien]);
      when(() => repo.cinemas()).thenAnswer((_) async => [trangTien]);
    },
    build: () => CinemasCubit(repo, city: 'Hà Nội'),
    act: (c) async {
      await c.load();
      await c.changeCity(null);
    },
    expect: () => const [
      CinemasState(city: 'Hà Nội'),
      CinemasState(city: 'Hà Nội', cinemas: [trangTien]),
      CinemasState(),
      CinemasState(cinemas: [trangTien]),
    ],
  );

  blocTest<CinemaScheduleCubit, CinemaScheduleState>(
    'an empty day offers the next date, which is added to the strip',
    setUp: () {
      final today = DateTime.utc(2026, 11, 24);
      final later = DateTime.utc(2026, 12, 3);
      when(() => repo.schedule(1, today)).thenAnswer(
        (_) async => CinemaSchedule(
          cinema: trangTien,
          date: today,
          movies: const [],
          nextAvailableDate: later,
        ),
      );
      when(() => repo.schedule(1, later)).thenAnswer(
        (_) async => CinemaSchedule(
          cinema: trangTien,
          date: later,
          movies: [
            MovieSlots(
              movieId: 7,
              title: 'Chợ Đêm',
              ageRating: 'T16',
              durationMin: 116,
              showtimes: [slot(1)],
            ),
          ],
        ),
      );
    },
    build: () =>
        CinemaScheduleCubit(repo, 1, today: DateTime.utc(2026, 11, 24)),
    act: (c) async {
      await c.load();
      await c.selectDate(c.state.data!.nextAvailableDate!);
    },
    verify: (c) {
      expect(c.state.days, hasLength(8));
      expect(c.state.data!.movies.single.title, 'Chợ Đêm');
    },
  );

  test('changing the Home city drops the answer for the old city', () async {
    final movies = _Movies();
    final slow = Completer<List<MovieSummary>>();
    when(
      () => movies.movies(status: MovieStatus.nowShowing),
    ).thenAnswer((_) => slow.future);
    when(
      () => movies.movies(status: MovieStatus.nowShowing, city: 'Hà Nội'),
    ).thenAnswer((_) async => [movie(2)]);
    when(
      () => movies.movies(status: MovieStatus.comingSoon),
    ).thenAnswer((_) async => []);
    final c = HomeCubit(movies);
    final first = c.load();
    await c.changeCity('Hà Nội');
    slow.complete([movie(1)]);
    await first;
    expect(c.state.nowShowing, [movie(2)]);
    await c.close();
  });

  test('recent searches survive a restart and can be cleared', () async {
    final p = await prefs();
    RecentSearches(p)
      ..add('Avengers')
      ..add('Chợ Đêm');
    final again = RecentSearches(p);
    expect(again.items, ['Chợ Đêm', 'Avengers']);
    again.clear();
    expect(RecentSearches(p).items, isEmpty);
  });
}
