import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/ticket.dart';
import '../../domain/ticket_repository.dart';

class TicketDetailState extends Equatable {
  const TicketDetailState({this.ticket, this.failure});

  final TicketDetail? ticket;
  final ApiFailure? failure;

  @override
  List<Object?> get props => [ticket, failure];
}

class TicketDetailCubit extends Cubit<TicketDetailState> {
  TicketDetailCubit(this._repo, this.id) : super(const TicketDetailState());

  final TicketRepository _repo;
  final int id;

  Future<void> load() async {
    emit(TicketDetailState(ticket: state.ticket));
    try {
      final t = await _repo.detail(id);
      if (!isClosed) emit(TicketDetailState(ticket: t));
    } on ApiFailure catch (f) {
      if (!isClosed) emit(TicketDetailState(ticket: state.ticket, failure: f));
    }
  }
}
