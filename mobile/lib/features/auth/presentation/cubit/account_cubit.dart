import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';
import '../../domain/auth_repository.dart';
import '../../domain/user.dart';

class AccountState extends Equatable {
  const AccountState({this.user, this.failure, this.loggingOut = false});

  final User? user;
  final ApiFailure? failure;
  final bool loggingOut;

  @override
  List<Object?> get props => [user, failure, loggingOut];
}

/// S14: profile from `GET /me` and logout.
class AccountCubit extends Cubit<AccountState> {
  AccountCubit(this._repo) : super(const AccountState());

  final AuthRepository _repo;

  Future<void> load() async {
    emit(AccountState(user: state.user));
    try {
      emit(AccountState(user: await _repo.me()));
    } on ApiFailure catch (f) {
      emit(AccountState(user: state.user, failure: f));
    }
  }

  /// The router moves to Login when the session ends.
  Future<void> logout() async {
    if (state.loggingOut) return;
    emit(AccountState(user: state.user, loggingOut: true));
    await _repo.logout();
  }
}
