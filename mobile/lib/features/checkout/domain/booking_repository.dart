import 'booking.dart';
import 'combo.dart';
import 'payment.dart';

/// Throws `ApiFailure` on errors. Who may see or cancel a booking is decided by the
/// backend (another user's booking is 404); the app only shows what comes back.
abstract interface class BookingRepository {
  /// Holds the seats for 10 minutes; replaces the user's earlier hold on this showtime.
  Future<Booking> hold(int showtimeId, List<int> seatIds);

  Future<Booking> get(int id);

  /// Releases the seats now. Safe to repeat.
  Future<void> cancel(int id);

  Future<List<Combo>> combos();

  /// Replaces the booking's combos (combo id → quantity); empty means none.
  Future<Booking> setCombos(int bookingId, Map<int, int> quantities);

  /// Mock payment. Sending the same [idempotencyKey] again returns the first attempt,
  /// so a retry after a timeout never pays twice.
  Future<Payment> pay(
    int bookingId,
    PaymentResult result, {
    required String idempotencyKey,
  });
}
