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

  Future<List<dynamic>> combos() async =>
      (await _dio.get<List<dynamic>>('/combos')).data!;

  Future<Map<String, dynamic>> setCombos(
    int id,
    List<Map<String, int>> items,
  ) async => (await _dio.put<Map<String, dynamic>>(
    '/bookings/$id/combos',
    data: {'items': items},
  )).data!;

  Future<Map<String, dynamic>> pay(
    int id,
    String result,
    String idempotencyKey,
  ) async => (await _dio.post<Map<String, dynamic>>(
    '/bookings/$id/payments',
    data: {'result': result},
    options: Options(headers: {'Idempotency-Key': idempotencyKey}),
  )).data!;
}
