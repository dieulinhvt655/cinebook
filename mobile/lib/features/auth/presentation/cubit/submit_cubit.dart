import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_failure.dart';

enum SubmitStatus { idle, submitting, success, failure }

class SubmitState extends Equatable {
  const SubmitState._(this.status, [this.failure]);

  const SubmitState.idle() : this._(SubmitStatus.idle);
  const SubmitState.submitting() : this._(SubmitStatus.submitting);
  const SubmitState.success() : this._(SubmitStatus.success);
  const SubmitState.failure(ApiFailure failure)
    : this._(SubmitStatus.failure, failure);

  final SubmitStatus status;
  final ApiFailure? failure;

  bool get isSubmitting => status == SubmitStatus.submitting;

  /// Server-side message for one form field (VALIDATION_FAILED), e.g. `email`.
  String? fieldError(String field) => failure?.fields[field];

  @override
  List<Object?> get props => [status, failure];
}

/// Shared by the login and register forms: one request at a time, failure kept until the
/// user edits the form again.
class SubmitCubit extends Cubit<SubmitState> {
  SubmitCubit() : super(const SubmitState.idle());

  Future<void> run(Future<void> Function() action) async {
    if (state.isSubmitting) return;
    emit(const SubmitState.submitting());
    try {
      await action();
      emit(const SubmitState.success());
    } on ApiFailure catch (f) {
      emit(SubmitState.failure(f));
    }
  }

  /// Hides a stale error once the user starts correcting the form.
  void edited() {
    if (state.status == SubmitStatus.failure) emit(const SubmitState.idle());
  }
}
