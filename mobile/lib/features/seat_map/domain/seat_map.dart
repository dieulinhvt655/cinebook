import 'package:equatable/equatable.dart';

/// Live status from the server. "Selected" is local to the device (design doc 3.2).
enum SeatStatus {
  available,
  held,
  sold;

  static SeatStatus parse(String s) => switch (s) {
    'SOLD' => sold,
    'HELD' => held,
    _ => available,
  };
}

/// STANDARD, VIP or COUPLE (backend `seat_types.code`).
enum SeatKind {
  standard,
  vip,
  couple;

  static SeatKind parse(String s) => switch (s) {
    'VIP' => vip,
    'COUPLE' => couple,
    _ => standard,
  };
}

class Seat extends Equatable {
  const Seat({
    required this.id,
    required this.row,
    required this.col,
    required this.kind,
    required this.price,
    required this.status,
    this.pairSeatId,
  });

  factory Seat.fromJson(Map<String, dynamic> json) => Seat(
    id: (json['id'] as num).toInt(),
    row: json['row'] as String,
    col: (json['col'] as num).toInt(),
    kind: SeatKind.parse(json['type'] as String),
    price: (json['price'] as num).toInt(),
    status: SeatStatus.parse(json['status'] as String),
    pairSeatId: (json['pairSeatId'] as num?)?.toInt(),
  );

  final int id;
  final String row;

  /// 1-based position on the room grid; a column with no seat is an aisle.
  final int col;
  final SeatKind kind;

  /// Base price of the showtime plus the seat type surcharge, for this one seat.
  final int price;
  final SeatStatus status;

  /// The other half of a couple seat; both are always selected together.
  final int? pairSeatId;

  /// "F7".
  String get label => '$row$col';

  bool get isAvailable => status == SeatStatus.available;

  @override
  List<Object?> get props => [id, row, col, kind, price, status, pairSeatId];
}

class SeatRow extends Equatable {
  const SeatRow({required this.label, required this.seats});

  factory SeatRow.fromJson(Map<String, dynamic> json) => SeatRow(
    label: json['label'] as String,
    seats: (json['seats'] as List<dynamic>)
        .map((e) => Seat.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String label;

  /// Ordered by column.
  final List<Seat> seats;

  @override
  List<Object?> get props => [label, seats];
}

/// Legend entry with its price, only for the types present in the room.
class SeatTypeInfo extends Equatable {
  const SeatTypeInfo({
    required this.kind,
    required this.name,
    required this.price,
  });

  factory SeatTypeInfo.fromJson(Map<String, dynamic> json) => SeatTypeInfo(
    kind: SeatKind.parse(json['code'] as String),
    name: json['name'] as String,
    price: (json['price'] as num).toInt(),
  );

  final SeatKind kind;
  final String name;
  final int price;

  @override
  List<Object?> get props => [kind, name, price];
}

/// S08 (backend `GET /showtimes/{id}/seats`).
class SeatMap extends Equatable {
  const SeatMap({
    required this.showtimeId,
    required this.startAt,
    required this.format,
    required this.subtitle,
    required this.bookable,
    required this.movieTitle,
    required this.ageRating,
    required this.cinemaName,
    required this.auditoriumName,
    required this.colCount,
    required this.seatTypes,
    required this.rows,
    required this.availableCount,
    required this.maxSeats,
    required this.serverTime,
  });

  factory SeatMap.fromJson(Map<String, dynamic> json) {
    final movie = json['movie'] as Map<String, dynamic>;
    final venue = json['venue'] as Map<String, dynamic>;
    return SeatMap(
      showtimeId: (json['showtimeId'] as num).toInt(),
      startAt: DateTime.parse(json['startAt'] as String),
      format: json['format'] as String,
      subtitle: json['subtitle'] as String,
      bookable: json['bookable'] as bool,
      movieTitle: movie['title'] as String,
      ageRating: movie['ageRating'] as String,
      cinemaName: venue['cinemaName'] as String,
      auditoriumName: venue['auditoriumName'] as String,
      colCount: (venue['colCount'] as num).toInt(),
      seatTypes: (json['seatTypes'] as List<dynamic>)
          .map((e) => SeatTypeInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      rows: (json['rows'] as List<dynamic>)
          .map((e) => SeatRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      availableCount: (json['availableCount'] as num).toInt(),
      maxSeats: (json['maxSeats'] as num).toInt(),
      serverTime: DateTime.parse(json['serverTime'] as String),
    );
  }

  final int showtimeId;
  final DateTime startAt;
  final String format;
  final String subtitle;

  /// False once online sales have closed (15 minutes before the start).
  final bool bookable;
  final String movieTitle;
  final String ageRating;
  final String cinemaName;
  final String auditoriumName;

  /// Width of the room grid; seats are placed by [Seat.col].
  final int colCount;
  final List<SeatTypeInfo> seatTypes;
  final List<SeatRow> rows;
  final int availableCount;

  /// Seats per booking (8).
  final int maxSeats;
  final DateTime serverTime;

  bool get soldOut => availableCount == 0;

  /// "2D Phụ đề", as on S07.
  String get versionLabel =>
      '$format ${subtitle == 'DUB' ? 'Lồng tiếng' : 'Phụ đề'}';

  Iterable<Seat> get seats => rows.expand((r) => r.seats);

  Seat? seatById(int id) {
    for (final s in seats) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    showtimeId,
    startAt,
    format,
    subtitle,
    bookable,
    movieTitle,
    ageRating,
    cinemaName,
    auditoriumName,
    colCount,
    seatTypes,
    rows,
    availableCount,
    maxSeats,
    serverTime,
  ];
}
