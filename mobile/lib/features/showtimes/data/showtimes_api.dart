import 'package:dio/dio.dart';

class ShowtimesApi {
  ShowtimesApi(this._dio);

  final Dio _dio;

  /// [date] is `yyyy-MM-dd`.
  Future<Map<String, dynamic>> forMovie(int movieId, String date) async =>
      (await _dio.get<Map<String, dynamic>>(
        '/movies/$movieId/showtimes',
        queryParameters: {'date': date},
      )).data!;
}
