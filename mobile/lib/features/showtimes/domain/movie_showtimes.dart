import 'package:equatable/equatable.dart';

import '../../../core/utils/formatters.dart';

/// One time chip on S07 (backend `ShowtimeSlot`).
class ShowtimeSlot extends Equatable {
  const ShowtimeSlot({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.format,
    required this.subtitle,
    required this.auditorium,
    required this.basePrice,
    required this.bookable,
    this.availableSeats,
  });

  factory ShowtimeSlot.fromJson(Map<String, dynamic> json) => ShowtimeSlot(
    id: (json['id'] as num).toInt(),
    startAt: DateTime.parse(json['startAt'] as String),
    endAt: DateTime.parse(json['endAt'] as String),
    format: json['format'] as String,
    subtitle: json['subtitle'] as String,
    auditorium: json['auditorium'] as String,
    basePrice: (json['basePrice'] as num).toInt(),
    bookable: json['bookable'] as bool,
    availableSeats: (json['availableSeats'] as num?)?.toInt(),
  );

  final int id;
  final DateTime startAt;
  final DateTime endAt;

  /// 2D, 3D or IMAX.
  final String format;

  /// SUB or DUB.
  final String subtitle;
  final String auditorium;
  final int basePrice;

  /// False once sales close (15 minutes before the start).
  final bool bookable;

  /// Seats neither sold nor held; null from an older backend.
  final int? availableSeats;

  /// Group heading on S07: "2D Phụ đề", "3D Lồng tiếng".
  String get versionLabel =>
      '$format ${subtitle == 'DUB' ? 'Lồng tiếng' : 'Phụ đề'}';

  @override
  List<Object?> get props => [
    id,
    startAt,
    endAt,
    format,
    subtitle,
    auditorium,
    basePrice,
    bookable,
    availableSeats,
  ];
}

class CinemaShowtimes extends Equatable {
  const CinemaShowtimes({
    required this.cinemaId,
    required this.name,
    required this.city,
    this.address,
    required this.showtimes,
  });

  factory CinemaShowtimes.fromJson(Map<String, dynamic> json) =>
      CinemaShowtimes(
        cinemaId: (json['cinemaId'] as num).toInt(),
        name: json['name'] as String,
        city: json['city'] as String,
        address: json['address'] as String?,
        showtimes: (json['showtimes'] as List<dynamic>)
            .map((e) => ShowtimeSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int cinemaId;
  final String name;
  final String city;
  final String? address;

  /// Sorted by start time.
  final List<ShowtimeSlot> showtimes;

  /// Slots grouped by [ShowtimeSlot.versionLabel], keeping time order inside each group.
  Map<String, List<ShowtimeSlot>> get byVersion {
    final groups = <String, List<ShowtimeSlot>>{};
    for (final s in showtimes) {
      (groups[s.versionLabel] ??= []).add(s);
    }
    return groups;
  }

  @override
  List<Object?> get props => [cinemaId, name, city, address, showtimes];
}

/// S07: one movie, one Vietnam day.
class MovieShowtimes extends Equatable {
  const MovieShowtimes({
    required this.movieId,
    required this.date,
    required this.cinemas,
    this.nextAvailableDate,
  });

  factory MovieShowtimes.fromJson(Map<String, dynamic> json) => MovieShowtimes(
    movieId: (json['movieId'] as num).toInt(),
    date: parseIsoDate(json['date'] as String),
    cinemas: (json['cinemas'] as List<dynamic>)
        .map((e) => CinemaShowtimes.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextAvailableDate: json['nextAvailableDate'] == null
        ? null
        : parseIsoDate(json['nextAvailableDate'] as String),
  );

  final int movieId;
  final DateTime date;
  final List<CinemaShowtimes> cinemas;

  /// Only set when [cinemas] is empty: the first later day that has showtimes.
  final DateTime? nextAvailableDate;

  @override
  List<Object?> get props => [movieId, date, cinemas, nextAvailableDate];
}
