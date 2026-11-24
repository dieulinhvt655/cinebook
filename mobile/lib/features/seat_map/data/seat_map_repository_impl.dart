import '../../../core/network/api_guard.dart';
import '../../../core/network/server_clock.dart';
import '../domain/seat_map.dart';
import '../domain/seat_map_repository.dart';
import 'seat_map_api.dart';

class SeatMapRepositoryImpl implements SeatMapRepository {
  SeatMapRepositoryImpl(this._api, this._clock);

  final SeatMapApi _api;
  final ServerClock _clock;

  /// Also syncs [ServerClock], so the hold countdown that follows starts from server time.
  @override
  Future<SeatMap> forShowtime(int showtimeId) => guardApi(() async {
    final map = SeatMap.fromJson(await _api.forShowtime(showtimeId));
    _clock.sync(map.serverTime);
    return map;
  });
}
