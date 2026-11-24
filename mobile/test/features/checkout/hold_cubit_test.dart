import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/checkout/domain/booking.dart';
import 'package:cinebook/features/checkout/domain/booking_repository.dart';
import 'package:cinebook/features/checkout/presentation/cubit/hold_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'booking_fixtures.dart';

class _Repo extends Mock implements BookingRepository {}

void main() {
  late _Repo repo;
  final booking = Booking.fromJson(bookingJson());
  const notFound = ApiFailure(code: 'NOT_FOUND', message: 'Không tìm thấy đơn');

  setUp(() => repo = _Repo());

  blocTest<HoldCubit, HoldState>(
    'loads the booking',
    setUp: () => when(() => repo.get(7)).thenAnswer((_) async => booking),
    build: () => HoldCubit(repo, 7),
    act: (c) => c.load(),
    expect: () => [const HoldState(), HoldState(booking: booking)],
  );

  blocTest<HoldCubit, HoldState>(
    'someone else\'s booking (404 from the server) shows the error',
    setUp: () => when(() => repo.get(7)).thenThrow(notFound),
    build: () => HoldCubit(repo, 7),
    act: (c) => c.load(),
    expect: () => [const HoldState(), const HoldState(failure: notFound)],
  );

  test('cancel reports whether the seats were released', () async {
    when(() => repo.cancel(7)).thenAnswer((_) async {});
    expect(await HoldCubit(repo, 7).cancel(), isTrue);

    when(() => repo.cancel(7)).thenThrow(notFound);
    expect(await HoldCubit(repo, 7).cancel(), isFalse);
  });
}
