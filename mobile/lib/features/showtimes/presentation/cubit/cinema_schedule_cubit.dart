import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/cinema.dart';
import '../../domain/cinema_repository.dart';

class CinemaScheduleState extends Equatable {
  const CinemaScheduleState({
    required this.days,
    required this.date,
    this.data,
    this.failure,
  });

  /// The next 7 days, plus [date] when it lies further out.
  final List<DateTime> days;
  final DateTime date;
  final CinemaSchedule? data;
  final ApiFailure? failure;

  bool get loading => data == null && failure == null;

  @override
  List<Object?> get props => [days, date, data, failure];
}

/// One cinema's showtimes by day ("Rạp" tab), S07 the other way round.
class CinemaScheduleCubit extends Cubit<CinemaScheduleState> {
  CinemaScheduleCubit(this._repo, this.cinemaId, {DateTime? today})
    : super(_initial(today ?? vietnamToday()));

  static const dayCount = 7;

  final CinemaRepository _repo;
  final int cinemaId;
  int _request = 0;

  static CinemaScheduleState _initial(DateTime today) => CinemaScheduleState(
    days: [for (var i = 0; i < dayCount; i++) today.add(Duration(days: i))],
    date: today,
  );

  Future<void> load() => selectDate(state.date);

  Future<void> selectDate(DateTime date) async {
    final id = ++_request;
    final base = state.days.take(dayCount).toList();
    final days = base.contains(date) ? base : [...base, date];
    emit(CinemaScheduleState(days: days, date: date));
    try {
      final data = await _repo.schedule(cinemaId, date);
      if (id != _request || isClosed) return;
      emit(CinemaScheduleState(days: days, date: date, data: data));
    } on ApiFailure catch (f) {
      if (id != _request || isClosed) return;
      emit(CinemaScheduleState(days: days, date: date, failure: f));
    }
  }
}
