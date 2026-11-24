import '../../../core/network/api_guard.dart';
import '../../../core/utils/formatters.dart';
import '../domain/cinema.dart';
import '../domain/cinema_repository.dart';
import 'cinemas_api.dart';

class CinemaRepositoryImpl implements CinemaRepository {
  CinemaRepositoryImpl(this._api);

  final CinemasApi _api;

  @override
  Future<List<City>> cities() => guardApi(
    () async => (await _api.cities())
        .map((e) => City.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  @override
  Future<List<Cinema>> cinemas({String? city}) => guardApi(
    () async => (await _api.cinemas(
      city: city,
    )).map((e) => Cinema.fromJson(e as Map<String, dynamic>)).toList(),
  );

  @override
  Future<CinemaSchedule> schedule(int cinemaId, DateTime date) => guardApi(
    () async => CinemaSchedule.fromJson(
      await _api.schedule(cinemaId, formatIsoDate(date)),
    ),
  );
}
