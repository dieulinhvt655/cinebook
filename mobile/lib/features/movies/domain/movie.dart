import 'package:equatable/equatable.dart';

import '../../../core/utils/formatters.dart';

/// Home tabs.
enum MovieStatus {
  nowShowing('NOW_SHOWING'),
  comingSoon('COMING_SOON');

  const MovieStatus(this.apiValue);

  final String apiValue;
}

List<String> _genres(Object? json) =>
    (json as List<dynamic>? ?? const []).cast<String>();

/// A poster card on Home and Search (backend `MovieSummary`).
class MovieSummary extends Equatable {
  const MovieSummary({
    required this.id,
    required this.title,
    this.posterUrl,
    this.bannerUrl,
    required this.ageRating,
    required this.durationMin,
    required this.releaseDate,
    this.genres = const [],
  });

  factory MovieSummary.fromJson(Map<String, dynamic> json) => MovieSummary(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    posterUrl: json['posterUrl'] as String?,
    bannerUrl: json['bannerUrl'] as String?,
    ageRating: json['ageRating'] as String,
    durationMin: (json['durationMin'] as num).toInt(),
    releaseDate: parseIsoDate(json['releaseDate'] as String),
    genres: _genres(json['genres']),
  );

  final int id;
  final String title;
  final String? posterUrl;
  final String? bannerUrl;

  /// P, K, T13, T16, T18.
  final String ageRating;
  final int durationMin;
  final DateTime releaseDate;
  final List<String> genres;

  @override
  List<Object?> get props => [
    id,
    title,
    posterUrl,
    bannerUrl,
    ageRating,
    durationMin,
    releaseDate,
    genres,
  ];
}

/// S06 (backend `MovieDetail`).
class MovieDetail extends Equatable {
  const MovieDetail({
    required this.id,
    required this.title,
    this.description,
    this.posterUrl,
    this.bannerUrl,
    required this.ageRating,
    required this.durationMin,
    required this.releaseDate,
    this.endDate,
    this.language,
    this.trailerUrl,
    this.genres = const [],
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) => MovieDetail(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    description: json['description'] as String?,
    posterUrl: json['posterUrl'] as String?,
    bannerUrl: json['bannerUrl'] as String?,
    ageRating: json['ageRating'] as String,
    durationMin: (json['durationMin'] as num).toInt(),
    releaseDate: parseIsoDate(json['releaseDate'] as String),
    endDate: json['endDate'] == null
        ? null
        : parseIsoDate(json['endDate'] as String),
    language: json['language'] as String?,
    trailerUrl: json['trailerUrl'] as String?,
    genres: _genres(json['genres']),
  );

  final int id;
  final String title;
  final String? description;
  final String? posterUrl;
  final String? bannerUrl;
  final String ageRating;
  final int durationMin;
  final DateTime releaseDate;
  final DateTime? endDate;
  final String? language;
  final String? trailerUrl;
  final List<String> genres;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    posterUrl,
    bannerUrl,
    ageRating,
    durationMin,
    releaseDate,
    endDate,
    language,
    trailerUrl,
    genres,
  ];
}
