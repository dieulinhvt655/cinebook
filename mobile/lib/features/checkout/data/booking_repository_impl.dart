import '../../../core/network/api_guard.dart';
import '../../../core/network/server_clock.dart';
import '../domain/booking.dart';
import '../domain/booking_repository.dart';
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

  /// Every booking response syncs [ServerClock], so the countdown follows the server.
  Future<Booking> _read(Future<Map<String, dynamic>> Function() call) =>
      guardApi(() async {
        final booking = Booking.fromJson(await call());
        _clock.sync(booking.serverTime);
        return booking;
      });
}
