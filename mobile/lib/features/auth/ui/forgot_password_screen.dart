import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import 'auth_layout.dart';

enum _Step { email, otp, password }

/// Email → OTP → new password, matching `/auth/forgot-password`,
/// `/auth/verify-reset-otp` and `/auth/reset-password`.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _Step _step = _Step.email;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _otp, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _next() async {
    if (!_form.currentState!.validate()) return;
    final api = ref.read(apiClientProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (_step) {
        case _Step.email:
          await api.post('/auth/forgot-password', body: {'email': _email.text.trim()});
          setState(() => _step = _Step.otp);
        case _Step.otp:
          await api.post('/auth/verify-reset-otp', body: {'email': _email.text.trim(), 'otp': _otp.text.trim()});
          setState(() => _step = _Step.password);
        case _Step.password:
          await api.post('/auth/reset-password', body: {
            'email': _email.text.trim(),
            'otp': _otp.text.trim(),
            'new_password': _password.text,
          });
          if (!mounted) return;
          showSnack(context, 'Password updated. Sign in with your new password.');
          context.go('/login');
      }
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, action) = switch (_step) {
      _Step.email => ('Reset your password', 'We\'ll email you a one-time code.', 'Send code'),
      _Step.otp => ('Check your email', 'Enter the code sent to ${_email.text.trim()}.', 'Verify code'),
      _Step.password => ('Choose a new password', 'Use at least 6 characters.', 'Update password'),
    };

    return AuthLayout(
      showBack: true,
      title: title,
      subtitle: subtitle,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step == _Step.email)
              TextFormField(
                controller: _email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onFieldSubmitted: (_) => _next(),
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                validator: Validators.email,
              ),
            if (_step == _Step.otp) ...[
              TextFormField(
                controller: _otp,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                onFieldSubmitted: (_) => _next(),
                decoration: const InputDecoration(labelText: 'Verification code', prefixIcon: Icon(Icons.pin_outlined)),
                validator: (v) => Validators.required(v, 'Code'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : () => setState(() => _step = _Step.email),
                  child: const Text('Use a different email'),
                ),
              ),
            ],
            if (_step == _Step.password) ...[
              TextFormField(
                controller: _password,
                obscureText: true,
                autofocus: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                validator: Validators.password,
              ),
              const SizedBox(height: Spacing.md),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                onFieldSubmitted: (_) => _next(),
                decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                validator: (v) => v == _password.text ? null : 'Passwords don\'t match',
              ),
            ],
            const SizedBox(height: Spacing.lg),
            if (_error != null) ErrorBanner(_error!),
            FilledButton(
              onPressed: _busy ? null : _next,
              child: _busy
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(action),
            ),
          ],
        ),
      ),
    );
  }
}
