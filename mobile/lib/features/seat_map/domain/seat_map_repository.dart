import 'seat_map.dart';

/// Throws `ApiFailure` on errors.
abstract interface class SeatMapRepository {
  Future<SeatMap> forShowtime(int showtimeId);
}
