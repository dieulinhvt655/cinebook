import 'package:cinebook/core/utils/formatters.dart';
import 'package:cinebook/features/showtimes/domain/movie_showtimes.dart';
import 'package:cinebook/features/showtimes/domain/showtime_repository.dart';
import 'package:cinebook/features/showtimes/presentation/cubit/showtime_cubit.dart';
import 'package:cinebook/features/showtimes/presentation/showtime_picker_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../movies/catalog_fixtures.dart';

class _Repo extends Mock implements ShowtimeRepository {}

void main() {
  late _Repo repo;
  final today = DateTime.utc(2026, 11, 22);

  setUpAll(() => initializeDateFormatting('vi'));
  setUp(() => repo = _Repo());

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => ShowtimeCubit(repo, 7, today: today)..load(),
          child: const ShowtimePickerView(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('closed showtimes are shown but cannot be tapped', (t) async {
    when(() => repo.forMovie(7, today)).thenAnswer(
      (_) async => MovieShowtimes(
        movieId: 7,
        date: today,
        cinemas: [
          cinema(1, 'Hồ Chí Minh', [
            slot(10, hourUtc: 2, bookable: false),
            slot(11, hourUtc: 5),
          ]),
        ],
      ),
    );
    await pump(t);

    expect(find.text('Rạp 1'), findsOneWidget);
    expect(find.text('2D Phụ đề'), findsOneWidget);
    final closed = t.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('09:00'),
        matching: find.byType(OutlinedButton),
      ),
    );
    final open = t.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('12:00'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(closed.onPressed, isNull);
    expect(open.onPressed, isNotNull);
  });

  testWidgets('an empty day says so and jumps to the suggested date', (
    t,
  ) async {
    final next = DateTime.utc(2026, 11, 25);
    when(() => repo.forMovie(7, today)).thenAnswer(
      (_) async => MovieShowtimes(
        movieId: 7,
        date: today,
        cinemas: const [],
        nextAvailableDate: next,
      ),
    );
    when(() => repo.forMovie(7, next)).thenAnswer(
      (_) async => MovieShowtimes(
        movieId: 7,
        date: next,
        cinemas: [
          cinema(3, 'Hà Nội', [slot(30)]),
        ],
      ),
    );
    await pump(t);

    expect(find.text('Không có suất chiếu ngày này'), findsOneWidget);
    await t.tap(find.text('Xem ngày ${formatDayChip(next)}'));
    await t.pumpAndSettle();

    expect(find.text('Rạp 3'), findsOneWidget);
    verify(() => repo.forMovie(7, next)).called(1);
  });
}
