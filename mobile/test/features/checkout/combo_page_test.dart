import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/core/network/server_clock.dart';
import 'package:cinebook/features/checkout/domain/booking.dart';
import 'package:cinebook/features/checkout/domain/booking_repository.dart';
import 'package:cinebook/features/checkout/domain/combo.dart';
import 'package:cinebook/features/checkout/presentation/combo_page.dart';
import 'package:cinebook/features/checkout/presentation/cubit/combos_cubit.dart';
import 'package:cinebook/features/checkout/presentation/cubit/hold_cubit.dart';
import 'package:cinebook/features/checkout/presentation/cubit/hold_timer_cubit.dart';
import 'package:cinebook/features/checkout/presentation/hold_expiry.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'booking_fixtures.dart';

class _Repo extends Mock implements BookingRepository {}

void main() {
  late _Repo repo;
  late DateTime deviceNow;
  late ServerClock clock;
  final booking = Booking.fromJson(bookingJson());

  setUp(() {
    repo = _Repo();
    deviceNow = DateTime.utc(2026, 11, 22, 5);
    clock = ServerClock(deviceNow: () => deviceNow);
    when(() => repo.get(7)).thenAnswer((_) async => booking);
    when(() => repo.combos()).thenAnswer(
      (_) async => [Combo.fromJson(comboSolo), Combo.fromJson(comboFamily)],
    );
  });

  /// S08 stand-in that opens S09, and an S10 stand-in that can leave normally or
  /// report an expired hold, like the real S10 does.
  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/hold'),
              child: const Text('S08'),
            ),
          ),
        ),
        GoRoute(
          path: '/hold',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => HoldCubit(repo, 7)..load()),
              BlocProvider(
                create: (_) => HoldTimerCubit(clock, listenToLifecycle: false),
              ),
              BlocProvider(create: (_) => CombosCubit(repo)..load()),
            ],
            child: const ComboView(),
          ),
        ),
        GoRoute(
          path: '/bookings/7/checkout',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('S10'),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('S10 back'),
                ),
                TextButton(
                  onPressed: () => context.pop(HoldExit.expired),
                  child: const Text('S10 expired'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.tap(find.text('S08'));
    await t.pumpAndSettle();
  }

  Finder add(String name) => find.byTooltip('Thêm $name');

  testWidgets('shows the countdown, the seats and the combos', (t) async {
    await pump(t);

    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Ghế: B1, B2'), findsOneWidget);
    expect(find.text('Combo Solo'), findsOneWidget);
    expect(find.text('Combo Family'), findsOneWidget);
    expect(find.text('210.000 đ'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);
  });

  testWidgets('steppers update the total and save before S10', (t) async {
    when(() => repo.setCombos(7, {1: 2})).thenAnswer(
      (_) async => Booking.fromJson(
        bookingJson(
          comboTotal: 158000,
          combos: [
            {
              'comboId': 1,
              'name': 'Combo Solo',
              'quantity': 2,
              'unitPrice': 79000,
            },
          ],
        ),
      ),
    );
    await pump(t);

    await t.tap(add('Combo Solo'));
    await t.tap(add('Combo Solo'));
    await t.pump();
    expect(find.text('368.000 đ'), findsOneWidget);

    await t.tap(find.text('Tiếp tục'));
    await t.pumpAndSettle();
    verify(() => repo.setCombos(7, {1: 2})).called(1);
    expect(find.text('S10'), findsOneWidget);

    // Back from S10: still on S09 with the hold.
    await t.tap(find.text('S10 back'));
    await t.pumpAndSettle();
    expect(find.text('Combo Solo'), findsOneWidget);
  });

  testWidgets('"Bỏ qua" without combos goes on without a request', (t) async {
    await pump(t);

    await t.tap(find.text('Bỏ qua'));
    await t.pumpAndSettle();

    verifyNever(() => repo.setCombos(any(), any()));
    expect(find.text('S10'), findsOneWidget);
  });

  testWidgets('a combo list that fails to load does not block "Bỏ qua"', (
    t,
  ) async {
    when(() => repo.combos()).thenThrow(
      const ApiFailure(code: ApiFailure.offline, message: 'Mất mạng'),
    );
    await pump(t);

    expect(find.textContaining('Không tải được combo'), findsOneWidget);
    await t.tap(find.text('Bỏ qua'));
    await t.pumpAndSettle();
    expect(find.text('S10'), findsOneWidget);
  });

  testWidgets('S10 reporting an expired hold closes S09 too', (t) async {
    await pump(t);
    await t.tap(find.text('Bỏ qua'));
    await t.pumpAndSettle();

    await t.tap(find.text('S10 expired'));
    await t.pumpAndSettle();

    expect(find.text('S08'), findsOneWidget);
    verifyNever(() => repo.cancel(any()));
  });

  testWidgets('Back asks "Huỷ giữ ghế?" and releases the seats', (t) async {
    when(() => repo.cancel(7)).thenAnswer((_) async {});
    await pump(t);

    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.text('Huỷ giữ ghế?'), findsOneWidget);

    await t.tap(find.text('Ở lại'));
    await t.pumpAndSettle();
    verifyNever(() => repo.cancel(7));

    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    await t.tap(find.text('Huỷ giữ ghế'));
    await t.pumpAndSettle();

    verify(() => repo.cancel(7)).called(1);
    expect(find.text('S08'), findsOneWidget);
  });

  testWidgets('time running out shows a dialog that only leads back to S08', (
    t,
  ) async {
    await pump(t);

    deviceNow = deviceNow.add(const Duration(minutes: 10));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.text('Hết thời gian giữ ghế'), findsOneWidget);

    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(find.text('Hết thời gian giữ ghế'), findsOneWidget);

    await t.tap(find.text('Chọn lại ghế'));
    await t.pumpAndSettle();
    expect(find.text('S08'), findsOneWidget);
  });

  testWidgets('a hold that already expired goes straight to the dialog', (
    t,
  ) async {
    when(
      () => repo.get(7),
    ).thenAnswer((_) async => Booking.fromJson(bookingJson(status: 'EXPIRED')));
    await pump(t);

    expect(find.text('Hết thời gian giữ ghế'), findsOneWidget);
  });
}
