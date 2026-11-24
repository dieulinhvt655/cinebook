import 'package:dio/dio.dart';

class CinemasApi {
  CinemasApi(this._dio);

  final Dio _dio;

  Future<List<dynamic>> cities() async =>
      (await _dio.get<List<dynamic>>('/cities')).data!;

  Future<List<dynamic>> cinemas({String? city}) async =>
      (await _dio.get<List<dynamic>>(
        '/cinemas',
        queryParameters: {'city': ?city},
      )).data!;

  /// [date] is `yyyy-MM-dd`.
  Future<Map<String, dynamic>> schedule(int cinemaId, String date) async =>
      (await _dio.get<Map<String, dynamic>>(
        '/cinemas/$cinemaId/showtimes',
        queryParameters: {'date': date},
      )).data!;
}
