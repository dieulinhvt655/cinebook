import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/movie_showtimes.dart';
import '../../domain/showtime_repository.dart';

class ShowtimeState extends Equatable {
  const ShowtimeState({
    required this.days,
    required this.date,
    this.city,
    this.data,
    this.failure,
  });

  /// Day chips: the next 7 days, plus [date] when it lies further out.
  final List<DateTime> days;
  final DateTime date;

  /// Null shows every city.
  final String? city;

  /// Showtimes of [date]; null while loading.
  final MovieShowtimes? data;
  final ApiFailure? failure;

  bool get loading => data == null && failure == null;

  /// Cities that have a showtime on [date], for the filter.
  List<String> get cities =>
      {...?data?.cinemas.map((c) => c.city), ?city}.toList()..sort();

  List<CinemaShowtimes> get cinemas => (data?.cinemas ?? const [])
      .where((c) => city == null || c.city == city)
      .toList();

  @override
  List<Object?> get props => [days, date, city, data, failure];
}

/// S07: showtimes by day; the city filter is applied on the device.
class ShowtimeCubit extends Cubit<ShowtimeState> {
  /// [city] starts the filter on the city picked on Home.
  ShowtimeCubit(this._repo, this.movieId, {DateTime? today, String? city})
    : super(_initial(today ?? vietnamToday(), city));

  static const dayCount = 7;

  final ShowtimeRepository _repo;
  final int movieId;
  int _request = 0;

  static ShowtimeState _initial(DateTime today, String? city) => ShowtimeState(
    days: [for (var i = 0; i < dayCount; i++) today.add(Duration(days: i))],
    date: today,
    city: city,
  );

  Future<void> load() => selectDate(state.date);

  Future<void> selectDate(DateTime date) async {
    final id = ++_request;
    final base = state.days.take(dayCount).toList();
    final days = base.contains(date) ? base : [...base, date];
    emit(ShowtimeState(days: days, date: date, city: state.city));
    try {
      final data = await _repo.forMovie(movieId, date);
      if (id != _request || isClosed) return;
      emit(ShowtimeState(days: days, date: date, city: state.city, data: data));
    } on ApiFailure catch (f) {
      if (id != _request || isClosed) return;
      emit(ShowtimeState(days: days, date: date, city: state.city, failure: f));
    }
  }

  void selectCity(String? city) => emit(
    ShowtimeState(
      days: state.days,
      date: state.date,
      city: city,
      data: state.data,
      failure: state.failure,
    ),
  );
}
