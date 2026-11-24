import 'package:equatable/equatable.dart';

import '../../../core/utils/formatters.dart';
import 'movie_showtimes.dart';

/// A city with active cinemas (backend `City`).
class City extends Equatable {
  const City({required this.name, required this.cinemaCount});

  factory City.fromJson(Map<String, dynamic> json) => City(
    name: json['name'] as String,
    cinemaCount: (json['cinemaCount'] as num).toInt(),
  );

  final String name;
  final int cinemaCount;

  @override
  List<Object?> get props => [name, cinemaCount];
}

/// "Rạp" tab (backend `CinemaInfo`).
class Cinema extends Equatable {
  const Cinema({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    this.phone,
  });

  factory Cinema.fromJson(Map<String, dynamic> json) => Cinema(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    city: json['city'] as String,
    address: json['address'] as String,
    phone: json['phone'] as String?,
  );

  final int id;
  final String name;
  final String city;
  final String address;
  final String? phone;

  @override
  List<Object?> get props => [id, name, city, address, phone];
}

/// One movie and its showtimes at a cinema.
class MovieSlots extends Equatable {
  const MovieSlots({
    required this.movieId,
    required this.title,
    this.posterUrl,
    required this.ageRating,
    required this.durationMin,
    required this.showtimes,
  });

  factory MovieSlots.fromJson(Map<String, dynamic> json) => MovieSlots(
    movieId: (json['movieId'] as num).toInt(),
    title: json['title'] as String,
    posterUrl: json['posterUrl'] as String?,
    ageRating: json['ageRating'] as String,
    durationMin: (json['durationMin'] as num).toInt(),
    showtimes: (json['showtimes'] as List<dynamic>)
        .map((e) => ShowtimeSlot.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final int movieId;
  final String title;
  final String? posterUrl;
  final String ageRating;
  final int durationMin;
  final List<ShowtimeSlot> showtimes;

  @override
  List<Object?> get props => [
    movieId,
    title,
    posterUrl,
    ageRating,
    durationMin,
    showtimes,
  ];
}

/// What one cinema shows on one Vietnam day (backend `CinemaSchedule`).
class CinemaSchedule extends Equatable {
  const CinemaSchedule({
    required this.cinema,
    required this.date,
    required this.movies,
    this.nextAvailableDate,
  });

  factory CinemaSchedule.fromJson(Map<String, dynamic> json) => CinemaSchedule(
    cinema: Cinema.fromJson(json['cinema'] as Map<String, dynamic>),
    date: parseIsoDate(json['date'] as String),
    movies: (json['movies'] as List<dynamic>)
        .map((e) => MovieSlots.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextAvailableDate: json['nextAvailableDate'] == null
        ? null
        : parseIsoDate(json['nextAvailableDate'] as String),
  );

  final Cinema cinema;
  final DateTime date;
  final List<MovieSlots> movies;

  /// Only set when [movies] is empty.
  final DateTime? nextAvailableDate;

  @override
  List<Object?> get props => [cinema, date, movies, nextAvailableDate];
}
