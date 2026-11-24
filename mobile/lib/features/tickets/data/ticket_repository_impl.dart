import '../../../core/network/api_guard.dart';
import '../domain/booking_history.dart';
import '../domain/ticket.dart';
import '../domain/ticket_repository.dart';
import 'tickets_api.dart';

class TicketRepositoryImpl implements TicketRepository {
  TicketRepositoryImpl(this._api);

  final TicketsApi _api;

  @override
  Future<List<TicketSummary>> mine(TicketScope scope) => guardApi(
    () async => [
      for (final t in await _api.mine(scope.name.toUpperCase()))
        TicketSummary.fromJson(t as Map<String, dynamic>),
    ],
  );

  @override
  Future<TicketDetail> detail(int id) =>
      guardApi(() async => TicketDetail.fromJson(await _api.detail(id)));

  @override
  Future<List<BookingHistoryItem>> history() => guardApi(
    () async => [
      for (final b in await _api.history())
        BookingHistoryItem.fromJson(b as Map<String, dynamic>),
    ],
  );
}
