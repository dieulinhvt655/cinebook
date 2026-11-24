import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/checkout/domain/booking.dart';
import 'package:cinebook/features/checkout/domain/booking_repository.dart';
import 'package:cinebook/features/seat_map/domain/seat_map.dart';
import 'package:cinebook/features/seat_map/domain/seat_map_repository.dart';
import 'package:cinebook/features/seat_map/presentation/cubit/seat_map_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../checkout/booking_fixtures.dart';
import 'seat_map_fixtures.dart';

class _Repo extends Mock implements SeatMapRepository {}

class _Bookings extends Mock implements BookingRepository {}

void main() {
  late _Repo repo;
  late _Bookings bookings;
  const offline = ApiFailure(code: ApiFailure.offline, message: 'Mất mạng');

  setUpAll(() => registerFallbackValue(<int>[]));

  setUp(() {
    repo = _Repo();
    bookings = _Bookings();
  });

  SeatMapCubit build() => SeatMapCubit(repo, bookings, 42);

  blocTest<SeatMapCubit, SeatMapState>(
    'loads the map; picking seats keeps a running total',
    setUp: () =>
        when(() => repo.forShowtime(42)).thenAnswer((_) async => seatMap()),
    build: build,
    act: (c) async {
      await c.load();
      final map = c.state.map!;
      c
        ..toggle(map.seat('A1'))
        ..toggle(map.seat('B1'))
        ..toggle(map.seat('C1'));
    },
    verify: (c) {
      expect(c.state.selectedSeats.map((s) => s.label), [
        'A1',
        'B1',
        'C1',
        'C2',
      ]);
      expect(c.state.total, 90000 + 105000 + 2 * 120000);
      expect(c.state.canContinue, isTrue);
    },
  );

  blocTest<SeatMapCubit, SeatMapState>(
    'a failed first load shows the error; retry recovers',
    setUp: () {
      var calls = 0;
      when(() => repo.forShowtime(42)).thenAnswer((_) async {
        if (calls++ == 0) throw offline;
        return seatMap();
      });
    },
    build: build,
    act: (c) async {
      await c.load();
      expect(c.state.failure, offline);
      expect(c.state.map, isNull);
      await c.load();
    },
    verify: (c) {
      expect(c.state.failure, isNull);
      expect(c.state.map, isNotNull);
    },
  );

  blocTest<SeatMapCubit, SeatMapState>(
    'on refresh, seats someone else took are dropped and named',
    setUp: () {
      var calls = 0;
      when(() => repo.forShowtime(42)).thenAnswer(
        (_) async => calls++ == 0
            ? seatMap()
            : seatMap(status: {'B2': 'HELD', 'B3': 'SOLD'}),
      );
    },
    build: build,
    act: (c) async {
      await c.load();
      final map = c.state.map!;
      for (final l in ['B1', 'B2', 'B3']) {
        c.toggle(map.seat(l));
      }
      await c.load();
    },
    verify: (c) {
      expect(c.state.selectedSeats.map((s) => s.label), ['B1']);
      expect(c.state.notice?.message, 'Ghế B2, B3 vừa được người khác chọn');
    },
  );

  blocTest<SeatMapCubit, SeatMapState>(
    'a failed refresh keeps the map and the selection',
    setUp: () {
      var calls = 0;
      when(() => repo.forShowtime(42)).thenAnswer((_) async {
        if (calls++ == 0) return seatMap();
        throw offline;
      });
    },
    build: build,
    act: (c) async {
      await c.load();
      c.toggle(c.state.map!.seat('B1'));
      await c.load();
    },
    verify: (c) {
      expect(c.state.map, isNotNull);
      expect(c.state.failure, isNull);
      expect(c.state.selectedSeats.single.label, 'B1');
      expect(c.state.notice?.message, 'Mất mạng');
    },
  );

  blocTest<SeatMapCubit, SeatMapState>(
    'the seat past the limit shows "Tối đa 8 ghế mỗi lần đặt"',
    setUp: () => when(
      () => repo.forShowtime(42),
    ).thenAnswer((_) async => seatMap(maxSeats: 2)),
    build: build,
    act: (c) async {
      await c.load();
      final map = c.state.map!;
      c
        ..toggle(map.seat('B1'))
        ..toggle(map.seat('B2'))
        ..toggle(map.seat('B3'));
    },
    verify: (c) {
      expect(c.state.selected, hasLength(2));
      expect(c.state.notice?.message, 'Tối đa 2 ghế mỗi lần đặt');
    },
  );

  blocTest<SeatMapCubit, SeatMapState>(
    '"Tiếp tục" refuses a selection that strands a single seat',
    setUp: () =>
        when(() => repo.forShowtime(42)).thenAnswer((_) async => seatMap()),
    build: build,
    act: (c) async {
      await c.load();
      final map = c.state.map!;
      c
        ..toggle(map.seat('B2'))
        ..toggle(map.seat('B3'));
      expect(c.confirm(), isNull);
      expect(
        c.state.notice?.message,
        'Không được để trống ghế lẻ B1, vui lòng chọn lại',
      );
      c.toggle(map.seat('B1'));
      expect(c.confirm()?.map((s) => s.label), ['B1', 'B2', 'B3']);
    },
  );

  blocTest<SeatMapCubit, SeatMapState>(
    'a showtime whose sales closed cannot be picked from',
    setUp: () => when(
      () => repo.forShowtime(42),
    ).thenAnswer((_) async => seatMap(bookable: false)),
    build: build,
    act: (c) async {
      await c.load();
      c.toggle(c.state.map!.seat('B1'));
    },
    verify: (c) {
      expect(c.state.selected, isEmpty);
      expect(c.state.canContinue, isFalse);
      expect(c.confirm(), isNull);
    },
  );

  test('notices get a new id each time, even with the same text', () async {
    when(
      () => repo.forShowtime(42),
    ).thenAnswer((_) async => seatMap(maxSeats: 1));
    final c = build();
    await c.load();
    final map = c.state.map!;
    c
      ..toggle(map.seat('B1'))
      ..toggle(map.seat('B2'));
    final first = c.state.notice;
    c.toggle(map.seat('B3'));
    expect(c.state.notice?.message, first?.message);
    expect(c.state.notice, isNot(first));
    await c.close();
  });

  test('ignores taps before the map is loaded', () {
    final c = build();
    c.toggle(
      const Seat(
        id: 1,
        row: 'A',
        col: 1,
        kind: SeatKind.standard,
        price: 1,
        status: SeatStatus.available,
      ),
    );
    expect(c.state.selected, isEmpty);
  });

  group('hold ("Tiếp tục")', () {
    final booking = Booking.fromJson(bookingJson());

    blocTest<SeatMapCubit, SeatMapState>(
      'sends the picked seat ids and returns the booking',
      setUp: () {
        when(() => repo.forShowtime(42)).thenAnswer((_) async => seatMap());
        when(() => bookings.hold(42, any())).thenAnswer((_) async => booking);
      },
      build: build,
      act: (c) async {
        await c.load();
        c.toggle(c.state.map!.seat('B1'));
        c.toggle(c.state.map!.seat('B2'));
        expect(await c.hold(), booking);
      },
      verify: (c) {
        final ids = c.state.map!.idsOf(['B1', 'B2']).toList();
        verify(() => bookings.hold(42, ids)).called(1);
        expect(c.state.holding, isFalse);
      },
    );

    blocTest<SeatMapCubit, SeatMapState>(
      'a seat taken meanwhile reloads the map and drops it from the selection',
      setUp: () {
        var calls = 0;
        when(() => repo.forShowtime(42)).thenAnswer(
          (_) async =>
              ++calls == 1 ? seatMap() : seatMap(status: {'B1': 'HELD'}),
        );
        when(() => bookings.hold(42, any())).thenThrow(
          const ApiFailure(
            code: 'SEAT_TAKEN',
            message: 'Ghế vừa được người khác chọn, vui lòng chọn ghế khác',
          ),
        );
      },
      build: build,
      act: (c) async {
        await c.load();
        c.toggle(c.state.map!.seat('B1'));
        c.toggle(c.state.map!.seat('B2'));
        expect(await c.hold(), isNull);
      },
      verify: (c) {
        verify(() => repo.forShowtime(42)).called(2);
        expect(c.state.selectedSeats.map((s) => s.label), ['B2']);
        expect(c.state.notice!.message, 'Ghế B1 vừa được người khác chọn');
      },
    );

    blocTest<SeatMapCubit, SeatMapState>(
      'other refusals show the server message without reloading',
      setUp: () {
        when(() => repo.forShowtime(42)).thenAnswer((_) async => seatMap());
        when(() => bookings.hold(42, any())).thenThrow(
          const ApiFailure(
            code: 'SEAT_LIMIT_EXCEEDED',
            message: 'Tối đa 8 ghế mỗi lần đặt',
          ),
        );
      },
      build: build,
      act: (c) async {
        await c.load();
        c.toggle(c.state.map!.seat('B1'));
        expect(await c.hold(), isNull);
      },
      verify: (c) {
        verify(() => repo.forShowtime(42)).called(1);
        expect(c.state.notice!.message, 'Tối đa 8 ghế mỗi lần đặt');
        expect(c.state.canContinue, isTrue);
      },
    );
  });
}
