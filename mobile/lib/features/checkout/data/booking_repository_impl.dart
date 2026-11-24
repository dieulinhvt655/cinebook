import '../../../core/network/api_guard.dart';
import '../../../core/network/server_clock.dart';
import '../domain/booking.dart';
import '../domain/booking_repository.dart';
import '../domain/combo.dart';
import '../domain/payment.dart';
import 'bookings_api.dart';

class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl(this._api, this._clock);

  final BookingsApi _api;
  final ServerClock _clock;

  @override
  Future<Booking> hold(int showtimeId, List<int> seatIds) =>
      _read(() => _api.hold(showtimeId, seatIds));

  @override
  Future<Booking> get(int id) => _read(() => _api.get(id));

  @override
  Future<void> cancel(int id) => guardApi(() => _api.cancel(id));

  @override
  Future<List<Combo>> combos() => guardApi(
    () async => [
      for (final c in await _api.combos())
        Combo.fromJson(c as Map<String, dynamic>),
    ],
  );

  @override
  Future<Booking> setCombos(int bookingId, Map<int, int> quantities) => _read(
    () => _api.setCombos(bookingId, [
      for (final e in quantities.entries)
        if (e.value > 0) {'comboId': e.key, 'quantity': e.value},
    ]),
  );

  @override
  Future<Payment> pay(
    int bookingId,
    PaymentResult result, {
    required String idempotencyKey,
  }) => guardApi(() async {
    final payment = Payment.fromJson(
      await _api.pay(bookingId, result.name.toUpperCase(), idempotencyKey),
    );
    _clock.sync(payment.booking.serverTime);
    return payment;
  });

  /// Every booking response syncs [ServerClock], so the countdown follows the server.
  Future<Booking> _read(Future<Map<String, dynamic>> Function() call) =>
      guardApi(() async {
        final booking = Booking.fromJson(await call());
        _clock.sync(booking.serverTime);
        return booking;
      });
}
