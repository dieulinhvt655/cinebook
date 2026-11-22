import 'package:dio/dio.dart';

class SeatMapApi {
  SeatMapApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> forShowtime(int showtimeId) async =>
      (await _dio.get<Map<String, dynamic>>(
        '/showtimes/$showtimeId/seats',
      )).data!;
}
