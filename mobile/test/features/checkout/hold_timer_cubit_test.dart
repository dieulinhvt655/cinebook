import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/server_clock.dart';
import 'package:cinebook/features/checkout/presentation/cubit/hold_timer_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime deviceNow;
  late ServerClock clock;

  setUp(() {
    deviceNow = DateTime.utc(2026, 11, 20, 10);
    clock = ServerClock(deviceNow: () => deviceNow);
  });

  HoldTimerCubit build() => HoldTimerCubit(clock, listenToLifecycle: false);

  blocTest<HoldTimerCubit, HoldTimerState>(
    'starts at 10:00 from the server expiresAt',
    build: build,
    act: (c) => c.start(deviceNow.add(const Duration(minutes: 10))),
    expect: () => [const HoldTimerState(Duration(minutes: 10))],
  );

  blocTest<HoldTimerCubit, HoldTimerState>(
    'corrects for a phone clock that runs 2 minutes fast',
    build: build,
    act: (c) {
      final serverNow = deviceNow.subtract(const Duration(minutes: 2));
      clock.sync(serverNow);
      c.start(serverNow.add(const Duration(minutes: 10)));
    },
    expect: () => [const HoldTimerState(Duration(minutes: 10))],
  );

  blocTest<HoldTimerCubit, HoldTimerState>(
    'recomputes from the clock (e.g. after background) instead of counting ticks',
    build: build,
    act: (c) {
      c.start(deviceNow.add(const Duration(minutes: 10)));
      deviceNow = deviceNow.add(const Duration(minutes: 9, seconds: 30));
      c.tick();
    },
    expect: () => [
      const HoldTimerState(Duration(minutes: 10)),
      const HoldTimerState(Duration(seconds: 30)),
    ],
    verify: (c) => expect(c.state.isWarning, isTrue),
  );

  blocTest<HoldTimerCubit, HoldTimerState>(
    'expires immediately when expiresAt is in the past',
    build: build,
    seed: () => const HoldTimerState(Duration(seconds: 5)),
    act: (c) => c.start(deviceNow.subtract(const Duration(seconds: 1))),
    expect: () => [const HoldTimerState(Duration.zero)],
    verify: (c) => expect(c.state.isExpired, isTrue),
  );
}
