import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/booking.dart';
import '../../domain/booking_repository.dart';

class HoldState extends Equatable {
  const HoldState({this.booking, this.failure, this.cancelling = false});

  /// Null until loaded.
  final Booking? booking;
  final ApiFailure? failure;
  final bool cancelling;

  @override
  List<Object?> get props => [booking, failure, cancelling];
}

/// The seat hold shown on S09/S10: loads it from the server and releases it on request.
class HoldCubit extends Cubit<HoldState> {
  HoldCubit(this._repo, this.bookingId) : super(const HoldState());

  final BookingRepository _repo;
  final int bookingId;

  Future<void> load() async {
    emit(HoldState(booking: state.booking));
    try {
      final booking = await _repo.get(bookingId);
      if (!isClosed) emit(HoldState(booking: booking));
    } on ApiFailure catch (f) {
      if (!isClosed) emit(HoldState(booking: state.booking, failure: f));
    }
  }

  /// "Huỷ giữ ghế": true when the seats were released. When it fails the seats are
  /// still freed when the hold expires, or replaced by the next hold on this showtime.
  Future<bool> cancel() async {
    if (state.cancelling) return false;
    emit(HoldState(booking: state.booking, cancelling: true));
    try {
      await _repo.cancel(bookingId);
      return true;
    } on ApiFailure {
      return false;
    } finally {
      if (!isClosed) emit(HoldState(booking: state.booking));
    }
  }
}
