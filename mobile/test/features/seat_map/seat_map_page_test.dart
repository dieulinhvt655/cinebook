import 'package:cinebook/features/seat_map/domain/seat_map_repository.dart';
import 'package:cinebook/features/seat_map/presentation/cubit/seat_map_cubit.dart';
import 'package:cinebook/features/seat_map/presentation/seat_map_page.dart';
import 'package:cinebook/features/seat_map/presentation/widgets/seat_tile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'seat_map_fixtures.dart';

class _Repo extends Mock implements SeatMapRepository {}

void main() {
  late _Repo repo;

  setUpAll(() => initializeDateFormatting('vi'));
  setUp(() => repo = _Repo());

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => SeatMapCubit(repo, 42)..load(),
          child: const SeatMapView(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Finder seat(String label) => find.byWidgetPredicate(
    (w) => w is SeatTile && w.seats.map((s) => s.label).contains(label),
  );

  FilledButton continueButton(WidgetTester t) => t.widget<FilledButton>(
    find.ancestor(
      of: find.text('Tiếp tục'),
      matching: find.byType(FilledButton),
    ),
  );

  testWidgets('shows the room with row labels, legend and an empty bar', (
    t,
  ) async {
    when(
      () => repo.forShowtime(42),
    ).thenAnswer((_) async => seatMap(status: {'A1': 'SOLD', 'A2': 'HELD'}));
    await pump(t);

    expect(find.text('Phim Thử'), findsOneWidget);
    expect(find.text('MÀN HÌNH'), findsOneWidget);
    expect(find.text('A'), findsNWidgets(2)); // both sides
    // 4 + 5 seats, the two couple pairs drawn as one tile each, plus C5.
    expect(find.byType(SeatTile), findsNWidgets(4 + 5 + 3));
    expect(find.text('Ghế đôi 120.000 đ'), findsOneWidget);
    expect(find.text('Chưa chọn ghế'), findsOneWidget);
    expect(continueButton(t).onPressed, isNull);
    expect(find.byIcon(Icons.close), findsWidgets); // sold cue (+ legend)
    expect(find.byIcon(Icons.schedule), findsWidgets); // held cue (+ legend)
  });

  testWidgets('tapping seats fills the bar; sold seats do nothing', (t) async {
    when(
      () => repo.forShowtime(42),
    ).thenAnswer((_) async => seatMap(status: {'A1': 'SOLD'}));
    await pump(t);

    await t.tap(seat('A1'));
    await t.tap(seat('B1'));
    await t.tap(seat('C1'));
    await t.pump();

    expect(find.text('Ghế: B1, C1, C2'), findsOneWidget);
    expect(find.text('345.000 đ'), findsOneWidget);
    expect(continueButton(t).onPressed, isNotNull);
  });

  testWidgets('a stranded single seat blocks "Tiếp tục" with a message', (
    t,
  ) async {
    when(() => repo.forShowtime(42)).thenAnswer((_) async => seatMap());
    await pump(t);

    await t.tap(seat('B2'));
    await t.pump();
    await t.tap(find.text('Tiếp tục'));
    await t.pump();

    expect(
      find.text('Không được để trống ghế lẻ B1, vui lòng chọn lại'),
      findsOneWidget,
    );
  });

  testWidgets('a sold-out showtime offers another one and hides the bar', (
    t,
  ) async {
    when(
      () => repo.forShowtime(42),
    ).thenAnswer((_) async => seatMap(availableCount: 0));
    await pump(t);

    expect(find.text('Đã hết vé'), findsOneWidget);
    expect(find.text('Chọn suất khác'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsNothing);
  });

  testWidgets('closed sales are explained', (t) async {
    when(
      () => repo.forShowtime(42),
    ).thenAnswer((_) async => seatMap(bookable: false));
    await pump(t);

    expect(find.text('Suất chiếu đã đóng bán online'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsNothing);
  });

  testWidgets('works on a 360 dp phone with large text', (t) async {
    t.view.physicalSize = const Size(360, 740);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    when(() => repo.forShowtime(42)).thenAnswer((_) async => seatMap());
    await pump(t);

    expect(t.takeException(), isNull);
    expect(t.getSize(seat('B1')).width, greaterThanOrEqualTo(24));
  });
}
