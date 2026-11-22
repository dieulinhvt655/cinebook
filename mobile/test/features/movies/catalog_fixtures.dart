import 'package:cinebook/features/movies/domain/movie.dart';
import 'package:cinebook/features/showtimes/domain/movie_showtimes.dart';

/// JSON as the backend sends it (dates `yyyy-MM-dd`, instants in UTC).
const movieJson = {
  'id': 7,
  'title': 'Avengers of the Abyss',
  'posterUrl': null,
  'bannerUrl': null,
  'ageRating': 'T13',
  'durationMin': 142,
  'releaseDate': '2026-11-14',
  'genres': ['Hành động', 'Viễn tưởng'],
};

MovieSummary movie(int id, {String title = 'Phim'}) => MovieSummary(
  id: id,
  title: '$title $id',
  ageRating: 'P',
  durationMin: 100,
  releaseDate: DateTime.utc(2026, 11, 1),
);

ShowtimeSlot slot(int id, {int hourUtc = 5, bool bookable = true}) =>
    ShowtimeSlot(
      id: id,
      startAt: DateTime.utc(2026, 11, 22, hourUtc),
      endAt: DateTime.utc(2026, 11, 22, hourUtc + 2),
      format: '2D',
      subtitle: 'SUB',
      auditorium: 'Phòng 1',
      basePrice: 90000,
      bookable: bookable,
    );

CinemaShowtimes cinema(int id, String city, List<ShowtimeSlot> slots) =>
    CinemaShowtimes(
      cinemaId: id,
      name: 'Rạp $id',
      city: city,
      showtimes: slots,
    );
