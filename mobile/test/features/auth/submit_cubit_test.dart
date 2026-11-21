import 'package:bloc_test/bloc_test.dart';
import 'package:cinebook/core/network/api_failure.dart';
import 'package:cinebook/features/auth/presentation/cubit/submit_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrong = ApiFailure(
    code: 'INVALID_CREDENTIALS',
    message: 'Email hoặc mật khẩu không chính xác',
    status: 401,
  );

  blocTest<SubmitCubit, SubmitState>(
    'submitting then success',
    build: SubmitCubit.new,
    act: (c) => c.run(() async {}),
    expect: () => const [SubmitState.submitting(), SubmitState.success()],
  );

  blocTest<SubmitCubit, SubmitState>(
    'keeps the failure until the user edits the form',
    build: SubmitCubit.new,
    act: (c) async {
      await c.run(() async => throw wrong);
      c.edited();
    },
    expect: () => const [
      SubmitState.submitting(),
      SubmitState.failure(wrong),
      SubmitState.idle(),
    ],
  );

  blocTest<SubmitCubit, SubmitState>(
    'ignores a second tap while a request is running',
    build: SubmitCubit.new,
    act: (c) async {
      var calls = 0;
      final first = c.run(() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await c.run(() async => calls++);
      await first;
      expect(calls, 1);
    },
    expect: () => const [SubmitState.submitting(), SubmitState.success()],
  );
}
