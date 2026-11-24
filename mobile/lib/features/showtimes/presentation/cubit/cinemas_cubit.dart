import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/cinema.dart';
import '../../domain/cinema_repository.dart';

class CinemasState extends Equatable {
  const CinemasState({this.city, this.cinemas, this.failure});

  final String? city;

  /// Null while loading.
  final List<Cinema>? cinemas;
  final ApiFailure? failure;

  bool get loading => cinemas == null && failure == null;

  @override
  List<Object?> get props => [city, cinemas, failure];
}

/// "Rạp" tab: cinemas of the chosen city.
class CinemasCubit extends Cubit<CinemasState> {
  CinemasCubit(this._repo, {String? city}) : super(CinemasState(city: city));

  final CinemaRepository _repo;
  int _request = 0;

  Future<void> load() => _fetch(state.city);

  /// The app-bar city changed; null shows every cinema.
  Future<void> changeCity(String? city) =>
      city == state.city && state.cinemas != null
      ? Future.value()
      : _fetch(city);

  Future<void> _fetch(String? city) async {
    final id = ++_request;
    emit(CinemasState(city: city));
    try {
      final cinemas = await _repo.cinemas(city: city);
      if (id != _request || isClosed) return;
      emit(CinemasState(city: city, cinemas: cinemas));
    } on ApiFailure catch (f) {
      if (id != _request || isClosed) return;
      emit(CinemasState(city: city, failure: f));
    }
  }
}
