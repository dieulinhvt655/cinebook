import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/booking_repository.dart';
import '../../domain/payment.dart';

/// One-off error for a snackbar; [id] changes for every new one.
class CheckoutNotice extends Equatable {
  const CheckoutNotice(this.id, this.failure);

  final int id;
  final ApiFailure failure;

  @override
  List<Object?> get props => [id, failure];
}

class CheckoutState extends Equatable {
  const CheckoutState({this.agreed = false, this.paying = false, this.notice});

  /// "Tôi đồng ý điều khoản" is ticked.
  final bool agreed;
  final bool paying;
  final CheckoutNotice? notice;

  bool get canPay => agreed && !paying;

  CheckoutState copyWith({
    bool? agreed,
    bool? paying,
    CheckoutNotice? notice,
  }) => CheckoutState(
    agreed: agreed ?? this.agreed,
    paying: paying ?? this.paying,
    notice: notice ?? this.notice,
  );

  @override
  List<Object?> get props => [agreed, paying, notice];
}

/// S10 (F6): mock payment. Each attempt gets an Idempotency-Key that is kept while the
/// answer is unknown (no network, timeout), so pressing again cannot pay twice; once the
/// server has answered, the next attempt gets a new key.
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._repo, this.bookingId, {String Function()? newKey})
    : _newKey = newKey ?? _randomKey,
      super(const CheckoutState());

  final BookingRepository _repo;
  final int bookingId;
  final String Function() _newKey;
  final Map<PaymentResult, String> _pendingKeys = {};
  int _notices = 0;

  void agree(bool value) => emit(state.copyWith(agreed: value));

  /// The payment, or null with a [CheckoutState.notice] (HOLD_EXPIRED included).
  Future<Payment?> pay(PaymentResult result) async {
    if (!state.canPay) return null;
    final key = _pendingKeys[result] ??= _newKey();
    emit(state.copyWith(paying: true));
    try {
      final payment = await _repo.pay(bookingId, result, idempotencyKey: key);
      _pendingKeys.clear();
      if (!isClosed) emit(state.copyWith(paying: false));
      return payment;
    } on ApiFailure catch (f) {
      if (!f.isConnectivity) _pendingKeys.clear();
      if (!isClosed) {
        emit(
          state.copyWith(paying: false, notice: CheckoutNotice(++_notices, f)),
        );
      }
      return null;
    }
  }

  static String _randomKey() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
