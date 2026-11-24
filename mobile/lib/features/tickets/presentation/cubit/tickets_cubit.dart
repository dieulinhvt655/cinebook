import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/ticket.dart';
import '../../domain/ticket_repository.dart';

class TicketsState extends Equatable {
  const TicketsState({
    this.tab = TicketScope.upcoming,
    this.lists = const {},
    this.failure,
    this.loading = false,
  });

  final TicketScope tab;

  /// Loaded tabs only.
  final Map<TicketScope, List<TicketSummary>> lists;
  final ApiFailure? failure;
  final bool loading;

  /// Null until the current tab has loaded.
  List<TicketSummary>? get visible => lists[tab];

  @override
  List<Object?> get props => [tab, lists, failure, loading];
}

/// S12: "Sắp tới" / "Đã xem". App-wide so a new payment can refresh it, and cleared on
/// sign-out so the next user never sees these tickets.
class TicketsCubit extends Cubit<TicketsState> {
  TicketsCubit(this._repo) : super(const TicketsState());

  final TicketRepository _repo;
  int _request = 0;

  /// Loads (or refreshes) the current tab; an answer for an older request is dropped.
  Future<void> load() async {
    final id = ++_request;
    final tab = state.tab;
    emit(TicketsState(tab: tab, lists: state.lists, loading: true));
    try {
      final list = await _repo.mine(tab);
      if (isClosed || id != _request) return;
      emit(TicketsState(tab: tab, lists: {...state.lists, tab: list}));
    } on ApiFailure catch (f) {
      if (isClosed || id != _request) return;
      emit(TicketsState(tab: tab, lists: state.lists, failure: f));
    }
  }

  Future<void> selectTab(TicketScope tab) async {
    if (tab == state.tab) return;
    emit(TicketsState(tab: tab, lists: state.lists));
    if (state.visible == null) await load();
  }

  /// Called after a payment: both tabs are stale; the current one reloads now.
  Future<void> refreshAll() async {
    emit(TicketsState(tab: state.tab));
    await load();
  }

  void clear() {
    _request++;
    emit(const TicketsState());
  }
}
