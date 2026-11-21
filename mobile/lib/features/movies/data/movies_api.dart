import 'package:dio/dio.dart';

/// Raw calls to `/movies`; responses come back as JSON.
class MoviesApi {
  MoviesApi(this._dio);

  final Dio _dio;

  Future<List<dynamic>> list({String? status, String? query}) async =>
      (await _dio.get<List<dynamic>>(
        '/movies',
        queryParameters: {'status': ?status, 'q': ?query},
      )).data!;

  Future<Map<String, dynamic>> detail(int id) async =>
      (await _dio.get<Map<String, dynamic>>('/movies/$id')).data!;
}
