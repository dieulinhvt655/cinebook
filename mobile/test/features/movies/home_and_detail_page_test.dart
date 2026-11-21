import 'package:cinebook/app/di.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/movies/domain/movie.dart';
import 'package:cinebook/features/movies/domain/movie_repository.dart';
import 'package:cinebook/features/movies/presentation/home_page.dart';
import 'package:cinebook/features/movies/presentation/movie_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog_fixtures.dart';

class _Repo extends Mock implements MovieRepository {}

void main() {
  late _Repo repo;

  setUp(() {
    repo = _Repo();
    sl.registerSingleton<MovieRepository>(repo);
  });

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
    await t.pumpWidget(const MaterialApp(home: HomePage()));
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
    await t.pumpWidget(const MaterialApp(home: HomePage()));
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
    await t.pumpWidget(const MaterialApp(home: MovieDetailPage(movieId: 7)));
    await t.pump();

    expect(find.text('Avengers of the Abyss'), findsWidgets);
    expect(find.text('T13'), findsOneWidget);
    expect(find.text('142 phút'), findsOneWidget);
    expect(find.text('Hành động, Viễn tưởng'), findsOneWidget);
    expect(find.byTooltip('Xem trailer'), findsOneWidget);
    expect(find.text('Đặt vé'), findsOneWidget);
    expect(find.text('Xem thêm'), findsOneWidget);
  });
}
