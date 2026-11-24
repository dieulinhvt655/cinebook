import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/core/network/server_clock.dart';
import 'package:cinebook/features/checkout/data/booking_repository_impl.dart';
import 'package:cinebook/features/checkout/data/bookings_api.dart';
import 'package:cinebook/features/checkout/domain/payment.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'booking_fixtures.dart';

class _Api extends Mock implements BookingsApi {}

void main() {
  late _Api api;
  late ServerClock clock;
  late BookingRepositoryImpl repo;
  final deviceNow = DateTime.utc(2026, 11, 22, 5, 3); // phone 3 minutes fast

  setUp(() {
    api = _Api();
    clock = ServerClock(deviceNow: () => deviceNow);
    repo = BookingRepositoryImpl(api, clock);
  });

  test('hold parses the booking and syncs the server clock', () async {
    when(() => api.hold(42, [11, 12])).thenAnswer((_) async => bookingJson());

    final b = await repo.hold(42, [11, 12]);

    expect(b.id, 7);
    expect(b.isHolding, isTrue);
    expect(b.seats.map((s) => s.label), ['B1', 'B2']);
    expect(b.totalAmount, 210000);
    expect(b.expiresAt, DateTime.utc(2026, 11, 22, 5, 10));
    expect(clock.now(), DateTime.utc(2026, 11, 22, 5));
  });

  test('409 SEAT_TAKEN becomes an ApiFailure with its message', () async {
    final req = RequestOptions(path: '/bookings');
    when(() => api.hold(42, [11])).thenThrow(
      DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: req,
          statusCode: 409,
          data: {
            'code': 'SEAT_TAKEN',
            'detail': 'Ghế vừa được người khác chọn',
          },
        ),
      ),
    );

    expect(
      () => repo.hold(42, [11]),
      throwsA(
        isA<ApiFailure>()
            .having((f) => f.code, 'code', 'SEAT_TAKEN')
            .having(
              (f) => f.message,
              'message',
              'Ghế vừa được người khác chọn',
            ),
      ),
    );
  });

  test('combos only send quantities above zero', () async {
    when(
      () => api.setCombos(7, [
        {'comboId': 1, 'quantity': 2},
      ]),
    ).thenAnswer((_) async => bookingJson(comboTotal: 158000));

    final b = await repo.setCombos(7, {1: 2, 3: 0});

    expect(b.totalAmount, 368000);
    expect(b.show.movieTitle, 'Phim Thử');
  });

  test('pay sends the result and the idempotency key', () async {
    when(
      () => api.pay(7, 'SUCCESS', 'k1'),
    ).thenAnswer((_) async => paymentJson());

    final p = await repo.pay(7, PaymentResult.success, idempotencyKey: 'k1');

    expect(p.succeeded, isTrue);
    expect(p.booking.status, 'PAID');
  });
}
