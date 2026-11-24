import 'package:cinebook/core/network/server_clock.dart';
import 'package:cinebook/features/checkout/domain/booking.dart';
import 'package:cinebook/features/checkout/domain/booking_repository.dart';
import 'package:cinebook/features/checkout/presentation/combo_page.dart';
import 'package:cinebook/features/checkout/presentation/cubit/hold_cubit.dart';
import 'package:cinebook/features/checkout/presentation/cubit/hold_timer_cubit.dart';
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

  setUp(() {
    repo = _Repo();
    deviceNow = DateTime.utc(2026, 11, 22, 5);
    clock = ServerClock(deviceNow: () => deviceNow);
  });

  /// S08 stand-in with a button that opens S09, like `context.push` does in the app.
  Future<void> pump(WidgetTester t) async {
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
            ],
            child: const ComboView(),
          ),
        ),
        GoRoute(
          path: '/bookings/7/checkout',
          builder: (_, _) => const Scaffold(body: Text('S10')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.tap(find.text('S08'));
    await t.pumpAndSettle();
  }

  testWidgets('shows the held seats, the countdown and the total', (t) async {
    when(
      () => repo.get(7),
    ).thenAnswer((_) async => Booking.fromJson(bookingJson()));
    await pump(t);

    expect(find.text('Ghế B1'), findsOneWidget);
    expect(find.text('Ghế B2'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('210.000 đ'), findsOneWidget);
  });

  testWidgets('Back asks "Huỷ giữ ghế?" and releases the seats', (t) async {
    when(
      () => repo.get(7),
    ).thenAnswer((_) async => Booking.fromJson(bookingJson()));
    when(() => repo.cancel(7)).thenAnswer((_) async {});
    await pump(t);

    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.text('Huỷ giữ ghế?'), findsOneWidget);

    await t.tap(find.text('Ở lại'));
    await t.pumpAndSettle();
    verifyNever(() => repo.cancel(7));
    expect(find.text('Ghế B1'), findsOneWidget);

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
    when(
      () => repo.get(7),
    ).thenAnswer((_) async => Booking.fromJson(bookingJson()));
    await pump(t);

    deviceNow = deviceNow.add(const Duration(minutes: 10));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.text('Hết thời gian giữ ghế'), findsOneWidget);

    // Neither the barrier nor Back closes it.
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(find.text('Hết thời gian giữ ghế'), findsOneWidget);

    await t.tap(find.text('Chọn lại ghế'));
    await t.pumpAndSettle();
    expect(find.text('S08'), findsOneWidget);
    verifyNever(() => repo.cancel(any()));
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

  testWidgets('time running out on S10 also leads back to S08', (t) async {
    when(
      () => repo.get(7),
    ).thenAnswer((_) async => Booking.fromJson(bookingJson()));
    await pump(t);
    await t.tap(find.text('Tiếp tục'));
    await t.pumpAndSettle();
    expect(find.text('S10'), findsOneWidget);

    deviceNow = deviceNow.add(const Duration(minutes: 10));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    await t.tap(find.text('Chọn lại ghế'));
    await t.pumpAndSettle();

    expect(find.text('S08'), findsOneWidget);
    expect(find.text('S10'), findsNothing);
  });
}
