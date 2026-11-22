import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/core/network/server_clock.dart';
import 'package:cinebook/features/seat_map/data/seat_map_api.dart';
import 'package:cinebook/features/seat_map/data/seat_map_repository_impl.dart';
import 'package:cinebook/features/seat_map/domain/seat_map.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'seat_map_fixtures.dart';

class _Api extends Mock implements SeatMapApi {}

void main() {
  test('parses the backend seat map', () {
    final map = SeatMap.fromJson(
      seatMapJson(status: {'A1': 'SOLD', 'A2': 'HELD'}),
    );
    expect(map.showtimeId, 42);
    expect(map.startAt, DateTime.utc(2026, 11, 22, 12, 30));
    expect(map.versionLabel, '2D Phụ đề');
    expect(map.cinemaName, 'CineBook Tràng Tiền');
    expect(map.colCount, 5);
    expect(map.rows.map((r) => r.label), ['A', 'B', 'C']);
    expect(map.seat('A1').status, SeatStatus.sold);
    expect(map.seat('A2').status, SeatStatus.held);
    expect(map.seat('B1').kind, SeatKind.vip);
    expect(map.seat('B1').price, 105000);
    expect(map.seat('C1').pairSeatId, map.seat('C2').id);
    expect(map.seat('A5').pairSeatId, isNull);
    expect(map.seatTypes.map((t) => t.kind), [
      SeatKind.standard,
      SeatKind.vip,
      SeatKind.couple,
    ]);
    expect(map.availableCount, 12);
    expect(map.soldOut, isFalse);
    expect(map.maxSeats, 8);
  });

  test('the repository syncs the server clock from serverTime', () async {
    final api = _Api();
    final device = DateTime.utc(2026, 11, 22, 5, 0, 30);
    final clock = ServerClock(deviceNow: () => device);
    when(() => api.forShowtime(42)).thenAnswer((_) async => seatMapJson());

    final map = await SeatMapRepositoryImpl(api, clock).forShowtime(42);

    expect(map.showtimeId, 42);
    expect(clock.offset, const Duration(seconds: -30));
  });

  test('a 404 becomes an ApiFailure with the server message', () async {
    final api = _Api();
    final request = RequestOptions(path: '/showtimes/9/seats');
    when(() => api.forShowtime(9)).thenThrow(
      DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 404,
          data: {'code': 'NOT_FOUND', 'detail': 'Không tìm thấy suất chiếu'},
        ),
      ),
    );

    await expectLater(
      SeatMapRepositoryImpl(api, ServerClock()).forShowtime(9),
      throwsA(
        isA<ApiFailure>()
            .having((f) => f.code, 'code', 'NOT_FOUND')
            .having((f) => f.message, 'message', 'Không tìm thấy suất chiếu'),
      ),
    );
  });
}
