import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/booking_history.dart';
import '../../domain/ticket_repository.dart';

class BookingHistoryState extends Equatable {
  const BookingHistoryState({this.items, this.failure, this.loading = false});

  /// Null until the first load succeeds.
  final List<BookingHistoryItem>? items;
  final ApiFailure? failure;
  final bool loading;

  @override
  List<Object?> get props => [items, failure, loading];
}

/// S14 "Lịch sử giao dịch". App-wide like the tickets, so a payment can refresh it and
/// sign-out can clear it before the next user signs in.
class BookingHistoryCubit extends Cubit<BookingHistoryState> {
  BookingHistoryCubit(this._repo) : super(const BookingHistoryState());

  final TicketRepository _repo;
  int _request = 0;

  /// Keeps the current list on screen while reloading; an older answer is dropped.
  Future<void> load() async {
    final id = ++_request;
    emit(BookingHistoryState(items: state.items, loading: true));
    try {
      final items = await _repo.history();
      if (isClosed || id != _request) return;
      emit(BookingHistoryState(items: items));
    } on ApiFailure catch (f) {
      if (isClosed || id != _request) return;
      emit(BookingHistoryState(items: state.items, failure: f));
    }
  }

  void clear() {
    _request++;
    emit(const BookingHistoryState());
  }
}
