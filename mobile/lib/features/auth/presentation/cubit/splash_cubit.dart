import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/auth_repository.dart';

/// S01. Null while checking; the failure when the server could not be reached. On success
/// the router leaves Splash by itself because the session status changes.
class SplashCubit extends Cubit<ApiFailure?> {
  SplashCubit(this._repo) : super(null);

  final AuthRepository _repo;

  Future<void> check() async {
    emit(null);
    try {
      await _repo.restoreSession();
    } on ApiFailure catch (f) {
      emit(f);
    }
  }
}
