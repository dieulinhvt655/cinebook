import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/checkout/domain/booking.dart';
import 'package:cinebook/features/checkout/domain/booking_repository.dart';
import 'package:cinebook/features/checkout/domain/combo.dart';
import 'package:cinebook/features/checkout/domain/payment.dart';
import 'package:cinebook/features/checkout/presentation/cubit/checkout_cubit.dart';
import 'package:cinebook/features/checkout/presentation/cubit/combos_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'booking_fixtures.dart';

class _Repo extends Mock implements BookingRepository {}

void main() {
  late _Repo repo;
  final solo = Combo.fromJson(comboSolo);
  final family = Combo.fromJson(comboFamily);
  const offline = ApiFailure(code: ApiFailure.offline, message: 'Mất mạng');

  setUpAll(() => registerFallbackValue(PaymentResult.success));
  setUp(() => repo = _Repo());

  group('CombosCubit', () {
    blocTest<CombosCubit, CombosState>(
      'steppers keep 0–10 per combo and preview the total',
      setUp: () =>
          when(() => repo.combos()).thenAnswer((_) async => [solo, family]),
      build: () => CombosCubit(repo),
      act: (c) async {
        await c.load();
        c
          ..remove(solo)
          ..add(solo)
          ..add(family)
          ..add(family);
        for (var i = 0; i < 12; i++) {
          c.add(solo);
        }
        c.remove(family);
      },
      verify: (c) {
        expect(c.state.quantities, {1: 10, 3: 1});
        expect(c.state.total, 10 * 79000 + 189000);
      },
    );

    test('saving unchanged picks needs no request', () async {
      final booking = Booking.fromJson(bookingJson());
      final c = CombosCubit(repo);
      expect(await c.save(booking), booking);
      verifyNever(() => repo.setCombos(any(), any()));
    });

    test('changed picks are sent and the server booking returned', () async {
      final booking = Booking.fromJson(bookingJson());
      final updated = Booking.fromJson(bookingJson(comboTotal: 79000));
      when(() => repo.setCombos(7, {1: 1})).thenAnswer((_) async => updated);
      final c = CombosCubit(repo)..add(solo);
      expect(await c.save(booking), updated);
      expect(c.state.saving, isFalse);
    });
  });

  group('CheckoutCubit', () {
    var keys = 0;
    CheckoutCubit build() =>
        CheckoutCubit(repo, 7, newKey: () => 'key-${++keys}')..agree(true);

    setUp(() => keys = 0);

    test('cannot pay before agreeing to the terms', () async {
      final c = CheckoutCubit(repo, 7);
      expect(c.state.canPay, isFalse);
      expect(await c.pay(PaymentResult.success), isNull);
      verifyNever(
        () => repo.pay(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    test(
      'a retry after a lost answer reuses the key, so it cannot pay twice',
      () async {
        final c = build();
        var calls = 0;
        when(
          () => repo.pay(
            7,
            PaymentResult.success,
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async {
          if (++calls == 1) throw offline;
          return Payment.fromJson(paymentJson());
        });

        expect(await c.pay(PaymentResult.success), isNull);
        expect(c.state.notice!.failure, offline);
        final payment = await c.pay(PaymentResult.success);

        expect(payment!.succeeded, isTrue);
        verify(
          () => repo.pay(7, PaymentResult.success, idempotencyKey: 'key-1'),
        ).called(2);
      },
    );

    test('after an answer the next attempt gets a new key', () async {
      final c = build();
      when(
        () => repo.pay(7, any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenAnswer(
        (_) async => Payment.fromJson(
          paymentJson(status: 'FAILED', bookingStatus: 'HOLDING'),
        ),
      );

      expect((await c.pay(PaymentResult.failed))!.succeeded, isFalse);
      await c.pay(PaymentResult.failed);

      verify(
        () => repo.pay(7, PaymentResult.failed, idempotencyKey: 'key-1'),
      ).called(1);
      verify(
        () => repo.pay(7, PaymentResult.failed, idempotencyKey: 'key-2'),
      ).called(1);
    });

    test('an expired hold is reported as a notice', () async {
      final c = build();
      const gone = ApiFailure(
        code: 'HOLD_EXPIRED',
        message: 'Hết thời gian giữ ghế',
        status: 410,
      );
      when(
        () => repo.pay(7, any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenThrow(gone);

      expect(await c.pay(PaymentResult.success), isNull);
      expect(c.state.notice!.failure.code, 'HOLD_EXPIRED');
      expect(c.state.paying, isFalse);
    });
  });
}
