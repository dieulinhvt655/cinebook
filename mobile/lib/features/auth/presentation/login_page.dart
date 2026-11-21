import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../domain/auth_repository.dart';
import 'auth_validators.dart';
import 'cubit/submit_cubit.dart';
import 'widgets/auth_form_widgets.dart';

/// S02. No "skip" button: the app has no guest mode.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (_) => SubmitCubit(), child: const LoginView());
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    // Empty or malformed fields never reach the server (BR-01.6, BR-04.1).
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final repo = sl<AuthRepository>();
    context.read<SubmitCubit>().run(
      () => repo.login(email: _email.text, password: _password.text),
    );
  }

  void _openRegister() {
    final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
    context.push(
      Uri(
        path: Routes.register,
        queryParameters: redirect == null ? null : {'redirect': redirect},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocConsumer<SubmitCubit, SubmitState>(
      // Keep the email, drop a password the server rejected (BR-04.6). After a network error
      // both stay so "Thử lại" works in one tap.
      listenWhen: (_, s) => s.failure?.code == 'INVALID_CREDENTIALS',
      listener: (_, _) => _password.clear(),
      builder: (context, state) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'CineBook',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Đăng nhập để đặt vé',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [
                        AutofillHints.email,
                        AutofillHints.username,
                      ],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: AuthValidators.email,
                      onChanged: (_) => context.read<SubmitCubit>().edited(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PasswordField(
                      controller: _password,
                      label: 'Mật khẩu',
                      validator: AuthValidators.loginPassword,
                      onChanged: (_) => context.read<SubmitCubit>().edited(),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (state.failure case final f?) ...[
                      const SizedBox(height: AppSpacing.md),
                      FormErrorBanner(message: f.message),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: state.failure?.isConnectivity == true
                          ? 'Thử lại'
                          : 'Đăng nhập',
                      loading: state.isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản?'),
                        TextButton(
                          onPressed: state.isSubmitting ? null : _openRegister,
                          child: const Text('Đăng ký'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
