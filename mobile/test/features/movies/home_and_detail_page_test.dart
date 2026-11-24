import 'package:cinebook/app/di.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/movies/domain/movie.dart';
import 'package:cinebook/features/movies/domain/movie_repository.dart';
import 'package:cinebook/features/movies/presentation/home_page.dart';
import 'package:cinebook/features/movies/presentation/movie_detail_page.dart';
import 'package:cinebook/core/storage/app_preferences.dart';
import 'package:cinebook/features/showtimes/domain/cinema.dart';
import 'package:cinebook/features/showtimes/domain/cinema_repository.dart';
import 'package:cinebook/features/showtimes/presentation/cubit/city_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog_fixtures.dart';

class _Repo extends Mock implements MovieRepository {}

class _Cinemas extends Mock implements CinemaRepository {}

void main() {
  late _Repo repo;
  late _Cinemas cinemas;
  late CityCubit city;

  setUp(() async {
    repo = _Repo();
    cinemas = _Cinemas();
    sl.registerSingleton<MovieRepository>(repo);
    SharedPreferences.setMockInitialValues({});
    city = CityCubit(
      cinemas,
      AppPreferences(await SharedPreferences.getInstance()),
    );
    when(() => cinemas.cities()).thenAnswer(
      (_) async => const [
        City(name: 'Hà Nội', cinemaCount: 2),
        City(name: 'TP. Hồ Chí Minh', cinemaCount: 1),
      ],
    );
  });

  Widget app(Widget home) => BlocProvider.value(
    value: city,
    child: MaterialApp(home: home),
  );

  tearDown(sl.reset);

  // Phone-sized screen, so the grid and the description are laid out.
  void phone(WidgetTester t) {
    t.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('Home shows now showing, then coming soon with release dates', (
    t,
  ) async {
    when(
      () => repo.movies(status: MovieStatus.nowShowing),
    ).thenAnswer((_) async => [movie(1), movie(2), movie(3)]);
    when(() => repo.movies(status: MovieStatus.comingSoon)).thenAnswer(
      (_) async => [
        MovieSummary(
          id: 9,
          title: 'Phim sắp chiếu có tên rất dài để thử xuống hai dòng',
          ageRating: 'T16',
          durationMin: 120,
          releaseDate: DateTime.utc(2026, 11, 25),
        ),
      ],
    );
    phone(t);
    await t.pumpWidget(app(const HomePage()));
    await t.pump();
    await t.pump();

    expect(find.text('Phim 2'), findsWidgets);
    await t.tap(find.text('Sắp chiếu'));
    await t.pump();
    expect(find.text('Khởi chiếu 25/11/2026'), findsOneWidget);
    expect(find.text('Phim 2'), findsNothing);

    // Let the carousel timer go before the widget is torn down.
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Home without a connection offers a retry', (t) async {
    when(() => repo.movies(status: any(named: 'status'))).thenThrow(
      const ApiFailure(code: ApiFailure.offline, message: 'Không có mạng'),
    );
    await t.pumpWidget(app(const HomePage()));
    await t.pump();

    expect(find.text('Không có mạng'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('Detail shows the movie and a booking button', (t) async {
    when(() => repo.detail(7)).thenAnswer(
      (_) async => MovieDetail.fromJson({
        ...movieJson,
        'description': 'Một câu chuyện rất dài. ' * 30,
        'endDate': null,
        'language': 'Tiếng Anh',
        'trailerUrl': 'https://www.youtube.com/watch?v=x',
      }),
    );
    phone(t);
    await t.pumpWidget(app(const MovieDetailPage(movieId: 7)));
    await t.pump();

    expect(find.text('Avengers of the Abyss'), findsWidgets);
    expect(find.text('T13'), findsOneWidget);
    expect(find.text('142 phút'), findsOneWidget);
    expect(find.text('Hành động, Viễn tưởng'), findsOneWidget);
    expect(find.byTooltip('Xem trailer'), findsOneWidget);
    expect(find.text('Đặt vé'), findsOneWidget);
    expect(find.text('Xem thêm'), findsOneWidget);
  });

  testWidgets('picking a city reloads now showing for that city', (t) async {
    when(
      () => repo.movies(
        status: MovieStatus.nowShowing,
        city: any(named: 'city'),
      ),
    ).thenAnswer((_) async => [movie(1)]);
    when(
      () => repo.movies(status: MovieStatus.comingSoon),
    ).thenAnswer((_) async => []);
    phone(t);
    await t.pumpWidget(app(const HomePage()));
    await t.pump();
    await t.pump();

    expect(find.text('Toàn quốc'), findsOneWidget);
    await t.tap(find.text('Toàn quốc'));
    await t.pumpAndSettle();
    await t.tap(find.text('Hà Nội'));
    await t.pumpAndSettle();

    expect(city.state.selected, 'Hà Nội');
    verify(
      () => repo.movies(status: MovieStatus.nowShowing, city: 'Hà Nội'),
    ).called(1);
    await t.pumpWidget(const SizedBox());
  });
}
