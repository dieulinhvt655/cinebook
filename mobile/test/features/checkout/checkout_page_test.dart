import 'package:cinebook/core/network/server_clock.dart';
import 'package:cinebook/features/checkout/domain/booking.dart';
import 'package:cinebook/features/checkout/domain/booking_repository.dart';
import 'package:cinebook/features/checkout/domain/payment.dart';
import 'package:cinebook/features/checkout/presentation/checkout_page.dart';
import 'package:cinebook/features/checkout/presentation/cubit/checkout_cubit.dart';
import 'package:cinebook/features/checkout/presentation/cubit/hold_cubit.dart';
import 'package:cinebook/features/checkout/presentation/cubit/hold_timer_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'booking_fixtures.dart';

class _Repo extends Mock implements BookingRepository {}

void main() {
  late _Repo repo;
  late DateTime deviceNow;
  late ServerClock clock;
  late Object? s09Got;

  setUpAll(() async {
    await initializeDateFormatting('vi');
    registerFallbackValue(PaymentResult.success);
  });

  setUp(() {
    repo = _Repo();
    deviceNow = DateTime.utc(2026, 11, 22, 5);
    clock = ServerClock(deviceNow: () => deviceNow);
    s09Got = 'nothing';
    when(() => repo.get(7)).thenAnswer(
      (_) async => Booking.fromJson(
        bookingJson(
          comboTotal: 79000,
          combos: [
            {
              'comboId': 1,
              'name': 'Combo Solo',
              'quantity': 1,
              'unitPrice': 79000,
            },
          ],
        ),
      ),
    );
  });

  /// S09 stand-in that records what S10 returns; S11 stand-in shows its query.
  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  s09Got = await context.push<Object>('/checkout'),
              child: const Text('S09'),
            ),
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => HoldCubit(repo, 7)..load()),
              BlocProvider(
                create: (_) => HoldTimerCubit(clock, listenToLifecycle: false),
              ),
              BlocProvider(
                create: (_) => CheckoutCubit(repo, 7, newKey: () => 'k'),
              ),
            ],
            child: const CheckoutView(),
          ),
        ),
        GoRoute(
          path: '/bookings/7/result',
          builder: (context, s) => Scaffold(
            appBar: AppBar(),
            body: Text('S11 ok=${s.uri.queryParameters['ok']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.tap(find.text('S09'));
    await t.pumpAndSettle();
  }

  FilledButton payButton(WidgetTester t) => t.widget<FilledButton>(
    find.ancestor(
      of: find.text('Giả lập thành công'),
      matching: find.byType(FilledButton),
    ),
  );

  testWidgets('shows the order, the age warning and needs the terms ticked', (
    t,
  ) async {
    await pump(t);

    expect(find.text('Phim Thử'), findsOneWidget);
    expect(find.text('Ghế B1'), findsOneWidget);
    expect(find.text('Combo Solo × 1'), findsOneWidget);
    expect(find.text('289.000 đ'), findsOneWidget);
    expect(find.textContaining('từ đủ 16 tuổi'), findsOneWidget);
    expect(find.textContaining('không thể huỷ hoặc hoàn tiền'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(payButton(t).onPressed, isNull);

    await t.tap(find.text('Tôi đồng ý điều khoản'));
    await t.pump();
    expect(payButton(t).onPressed, isNotNull);
  });

  testWidgets('success replaces the booking flow with S11', (t) async {
    when(
      () => repo.pay(7, PaymentResult.success, idempotencyKey: 'k'),
    ).thenAnswer((_) async => Payment.fromJson(paymentJson()));
    await pump(t);

    await t.tap(find.text('Tôi đồng ý điều khoản'));
    await t.pump();
    await t.tap(find.text('Giả lập thành công'));
    await t.pumpAndSettle();

    expect(find.text('S11 ok=1'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing); // nothing left to go back to
  });

  testWidgets(
    'failure opens S11 on top; "Thử lại" returns with the same timer',
    (t) async {
      when(
        () => repo.pay(7, PaymentResult.failed, idempotencyKey: 'k'),
      ).thenAnswer(
        (_) async => Payment.fromJson(
          paymentJson(status: 'FAILED', bookingStatus: 'HOLDING'),
        ),
      );
      await pump(t);
      await t.tap(find.text('Tôi đồng ý điều khoản'));
      await t.pump();
      await t.tap(find.text('Giả lập thất bại'));
      await t.pumpAndSettle();
      expect(find.text('S11 ok=0'), findsOneWidget);

      deviceNow = deviceNow.add(const Duration(minutes: 2));
      await t.tap(find.byType(BackButton));
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(find.text('08:00'), findsOneWidget);
    },
  );

  testWidgets('running out of time on S11 goes back past S09 to S08', (
    t,
  ) async {
    when(
      () => repo.pay(7, PaymentResult.failed, idempotencyKey: 'k'),
    ).thenAnswer(
      (_) async => Payment.fromJson(
        paymentJson(status: 'FAILED', bookingStatus: 'HOLDING'),
      ),
    );
    await pump(t);
    await t.tap(find.text('Tôi đồng ý điều khoản'));
    await t.pump();
    await t.tap(find.text('Giả lập thất bại'));
    await t.pumpAndSettle();

    deviceNow = deviceNow.add(const Duration(minutes: 10));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.text('Hết thời gian giữ ghế'), findsOneWidget);
    await t.tap(find.text('Chọn lại ghế'));
    await t.pumpAndSettle();

    expect(find.text('S09'), findsOneWidget);
    expect(s09Got.toString(), 'HoldExit.expired');
  });
}
