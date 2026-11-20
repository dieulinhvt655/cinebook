import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/server_clock.dart';

class HoldTimerState extends Equatable {
  const HoldTimerState(this.remaining);

  final Duration remaining;

  bool get isExpired => remaining == Duration.zero;

  /// Last minute: banner turns orange and the phone vibrates once.
  bool get isWarning => !isExpired && remaining <= const Duration(minutes: 1);

  @override
  List<Object?> get props => [remaining];
}

/// 10-minute seat-hold countdown, always derived from the server's `expiresAt`:
/// `remaining = expiresAt - serverNow`. It never counts down from a stored number, so it
/// stays correct after the app was in the background (recomputed on resume).
class HoldTimerCubit extends Cubit<HoldTimerState> {
  HoldTimerCubit(this._clock, {bool listenToLifecycle = true})
    : super(const HoldTimerState(Duration.zero)) {
    if (listenToLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: tick);
    }
  }

  final ServerClock _clock;
  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  DateTime? _expiresAt;

  void start(DateTime expiresAt) {
    _expiresAt = expiresAt;
    _timer?.cancel();
    tick();
    if (!state.isExpired) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }

  @visibleForTesting
  void tick() {
    final expiresAt = _expiresAt;
    if (expiresAt == null || isClosed) return;
    final left = expiresAt.difference(_clock.now());
    if (left <= Duration.zero) {
      _timer?.cancel();
      emit(const HoldTimerState(Duration.zero));
    } else {
      // Round up so 00:00 is only shown once the hold has really expired.
      emit(
        HoldTimerState(Duration(seconds: (left.inMilliseconds / 1000).ceil())),
      );
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _lifecycle?.dispose();
    return super.close();
  }
}
