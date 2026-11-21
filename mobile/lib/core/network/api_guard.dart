import 'package:dio/dio.dart';

import 'api_failure.dart';

/// Runs a call and turns a [DioException] into an [ApiFailure] for the UI.
Future<T> guardApi<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on DioException catch (e) {
    throw ApiFailure.fromDio(e);
  }
}
