import 'package:cinebook/features/showtimes/domain/movie_showtimes.dart';
import 'package:cinebook/features/movies/domain/movie.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_fixtures.dart';

void main() {
  test('movie summary parses dates as calendar days and null artwork', () {
    final m = MovieSummary.fromJson(movieJson);
    expect(m.id, 7);
    expect(m.releaseDate, DateTime.utc(2026, 11, 14));
    expect(m.posterUrl, isNull);
    expect(m.genres, ['Hành động', 'Viễn tưởng']);
  });

  test('showtimes parse instants, group by version and keep order', () {
    final data = MovieShowtimes.fromJson({
      'movieId': 7,
      'date': '2026-11-22',
      'nextAvailableDate': null,
      'cinemas': [
        {
          'cinemaId': 1,
          'name': 'CineBook Quận 1',
          'city': 'Hồ Chí Minh',
          'address': '1 Lê Lợi',
          'showtimes': [
            {
              'id': 10,
              'startAt': '2026-11-22T02:00:00Z',
              'endAt': '2026-11-22T04:22:00Z',
              'format': '2D',
              'subtitle': 'SUB',
              'auditorium': 'Phòng 1',
              'basePrice': 90000,
              'bookable': false,
            },
            {
              'id': 11,
              'startAt': '2026-11-22T05:00:00Z',
              'endAt': '2026-11-22T07:22:00Z',
              'format': '3D',
              'subtitle': 'DUB',
              'auditorium': 'Phòng 2',
              'basePrice': 120000,
              'bookable': true,
              'availableSeats': 116,
            },
            {
              'id': 12,
              'startAt': '2026-11-22T08:00:00Z',
              'endAt': '2026-11-22T10:22:00Z',
              'format': '2D',
              'subtitle': 'SUB',
              'auditorium': 'Phòng 1',
              'basePrice': 90000,
              'bookable': true,
            },
          ],
        },
      ],
    });
    final c = data.cinemas.single;
    expect(c.showtimes.first.startAt, DateTime.utc(2026, 11, 22, 2));
    expect(c.showtimes.first.bookable, isFalse);
    expect(c.showtimes.first.availableSeats, isNull); // older backend
    expect(c.showtimes[1].availableSeats, 116);
    expect(c.byVersion.keys, ['2D Phụ đề', '3D Lồng tiếng']);
    expect(c.byVersion['2D Phụ đề']!.map((s) => s.id), [10, 12]);
    expect(data.nextAvailableDate, isNull);
  });
}
