import 'package:dio/dio.dart';

class BookingsApi {
  BookingsApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> hold(int showtimeId, List<int> seatIds) async =>
      (await _dio.post<Map<String, dynamic>>(
        '/bookings',
        data: {'showtimeId': showtimeId, 'seatIds': seatIds},
      )).data!;

  Future<Map<String, dynamic>> get(int id) async =>
      (await _dio.get<Map<String, dynamic>>('/bookings/$id')).data!;

  Future<void> cancel(int id) => _dio.delete<void>('/bookings/$id');
}
