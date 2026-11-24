import 'package:dio/dio.dart';

class TicketsApi {
  TicketsApi(this._dio);

  final Dio _dio;

  /// [scope] is UPCOMING or PAST.
  Future<List<dynamic>> mine(String scope) async =>
      (await _dio.get<List<dynamic>>(
        '/me/tickets',
        queryParameters: {'scope': scope},
      )).data!;

  Future<Map<String, dynamic>> detail(int id) async =>
      (await _dio.get<Map<String, dynamic>>('/tickets/$id')).data!;

  Future<List<dynamic>> history() async =>
      (await _dio.get<List<dynamic>>('/me/bookings')).data!;
}
