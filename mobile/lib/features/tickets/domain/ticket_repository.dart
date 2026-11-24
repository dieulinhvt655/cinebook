import 'booking_history.dart';
import 'ticket.dart';

/// Throws `ApiFailure` on errors. Only the signed-in user's paid bookings come back;
/// another user's ticket is 404 from the server.
abstract interface class TicketRepository {
  Future<List<TicketSummary>> mine(TicketScope scope);

  Future<TicketDetail> detail(int id);

  /// The user's newest bookings in every status (S14 "Lịch sử giao dịch").
  Future<List<BookingHistoryItem>> history();
}
