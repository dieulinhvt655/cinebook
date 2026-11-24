import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../domain/cinema.dart';
import '../../domain/cinema_repository.dart';

class CityState extends Equatable {
  const CityState({this.cities = const [], this.selected});

  final List<City> cities;

  /// Null means every city ("Toàn quốc").
  final String? selected;

  @override
  List<Object?> get props => [cities, selected];
}

/// The city picked in the Home app bar, shared by Home, S07 and the "Rạp" tab and kept on
/// the device between launches.
class CityCubit extends Cubit<CityState> {
  CityCubit(this._repo, this._prefs) : super(CityState(selected: _prefs.city));

  final CinemaRepository _repo;
  final AppPreferences _prefs;

  /// Loads the list; a saved city that no longer has cinemas falls back to every city. A
  /// failure keeps the saved choice, the picker just has nothing new to offer.
  Future<void> load() async {
    try {
      final cities = await _repo.cities();
      final selected = cities.any((c) => c.name == state.selected)
          ? state.selected
          : null;
      if (selected != state.selected) await _prefs.setCity(selected);
      emit(CityState(cities: cities, selected: selected));
    } on ApiFailure {
      // Not worth an error screen: the app works with every city.
    }
  }

  Future<void> select(String? city) async {
    if (city == state.selected) return;
    emit(CityState(cities: state.cities, selected: city));
    await _prefs.setCity(city);
  }
}
