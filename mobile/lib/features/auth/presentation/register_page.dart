import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../domain/auth_repository.dart';
import '../domain/register_input.dart';
import 'auth_validators.dart';
import 'cubit/submit_cubit.dart';
import 'widgets/auth_form_widgets.dart';

/// S03. On success the backend signs the user in and the router leaves this screen.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (_) => SubmitCubit(), child: const RegisterView());
}

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  DateTime? _dateOfBirth;
  bool _acceptedTerms = false;
  bool _showTermsError = false;

  @override
  void dispose() {
    for (final c in [_fullName, _email, _phone, _dob, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _edited() => context.read<SubmitCubit>().edited();

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Chọn ngày sinh',
    );
    if (picked == null) return;
    setState(() {
      _dateOfBirth = picked;
      _dob.text = DateFormat('dd/MM/yyyy').format(picked);
    });
    _edited();
  }

  void _submit() {
    final valid = _form.currentState!.validate();
    setState(() => _showTermsError = !_acceptedTerms);
    if (!valid || !_acceptedTerms) return;
    FocusScope.of(context).unfocus();
    final phone = _phone.text.trim();
    final input = RegisterInput(
      email: _email.text.trim(),
      password: _password.text,
      fullName: _fullName.text.trim(),
      phone: phone.isEmpty ? null : phone,
      dateOfBirth: _dateOfBirth,
    );
    final repo = sl<AuthRepository>();
    context.read<SubmitCubit>().run(() => repo.register(input));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubmitCubit, SubmitState>(
      builder: (context, state) {
        // Field errors from the server sit under their field; anything else goes in the banner.
        final failure = state.failure;
        final bannerMessage = failure == null
            ? null
            : failure.fields.isEmpty
            ? failure.message
            : null;
        return Scaffold(
          appBar: AppBar(title: const Text('Đăng ký')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _fullName,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(labelText: 'Họ tên'),
                        validator: AuthValidators.fullName,
                        forceErrorText: state.fieldError('fullName'),
                        onChanged: (_) => _edited(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: AuthValidators.email,
                        // EMAIL_TAKEN comes back without `fields`; show it under the field.
                        forceErrorText:
                            state.fieldError('email') ??
                            (failure?.code == 'EMAIL_TAKEN'
                                ? failure!.message
                                : null),
                        onChanged: (_) => _edited(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại (không bắt buộc)',
                        ),
                        validator: AuthValidators.phone,
                        forceErrorText: state.fieldError('phone'),
                        onChanged: (_) => _edited(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _dob,
                        readOnly: true,
                        onTap: _pickDateOfBirth,
                        decoration: const InputDecoration(
                          labelText: 'Ngày sinh (không bắt buộc)',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        forceErrorText: state.fieldError('dateOfBirth'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PasswordField(
                        controller: _password,
                        label: 'Mật khẩu',
                        isNewPassword: true,
                        textInputAction: TextInputAction.next,
                        validator: AuthValidators.newPassword,
                        errorText: state.fieldError('password'),
                        onChanged: (_) => _edited(),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(
                          top: AppSpacing.xxs,
                          left: AppSpacing.sm,
                        ),
                        child: Text(
                          'Ít nhất ${AuthValidators.passwordMin} ký tự. Có thể dùng một '
                          'câu dễ nhớ, có dấu cách; không bắt buộc chữ hoa hay ký tự đặc biệt.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PasswordField(
                        controller: _confirm,
                        label: 'Nhập lại mật khẩu',
                        isNewPassword: true,
                        validator: (v) =>
                            AuthValidators.confirmPassword(v, _password.text),
                        onChanged: (_) => _edited(),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      CheckboxListTile(
                        value: _acceptedTerms,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Tôi đồng ý với điều khoản sử dụng'),
                        subtitle: _showTermsError && !_acceptedTerms
                            ? const Text(
                                'Vui lòng đồng ý điều khoản để tiếp tục',
                                style: TextStyle(color: AppColors.error),
                              )
                            : null,
                        onChanged: (v) =>
                            setState(() => _acceptedTerms = v ?? false),
                      ),
                      if (bannerMessage != null &&
                          failure?.code != 'EMAIL_TAKEN') ...[
                        const SizedBox(height: AppSpacing.xs),
                        FormErrorBanner(message: bannerMessage),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Đăng ký',
                        loading: state.isSubmitting,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
