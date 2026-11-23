import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import 'auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _totp = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _needs2fa = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _totp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(
            _email.text,
            _password.text,
            totpCode: _needs2fa ? _totp.text.trim() : null,
          );
      // The router redirect takes over once the session is set.
    } on TwoFactorRequired catch (e) {
      setState(() {
        if (_needs2fa) _error = e.message;
        _needs2fa = true;
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: _needs2fa ? 'Two-step verification' : 'Welcome back',
      subtitle: _needs2fa
          ? 'Enter the 6-digit code from your authenticator app.'
          : 'Sign in to your TruERP account',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_needs2fa) ...[
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: Spacing.md),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => Validators.required(v, 'Password'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _totp,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall?.copyWith(letterSpacing: 8),
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(hintText: '000000'),
                  validator: (v) => (v ?? '').trim().length == 6
                      ? null
                      : 'Enter the 6-digit code',
                ),
                const SizedBox(height: Spacing.md),
              ],
              if (_error != null) ErrorBanner(_error!),
              const SizedBox(height: Spacing.sm),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(_needs2fa ? 'Verify' : 'Sign in'),
              ),
              if (_needs2fa)
                TextButton(
                  onPressed: () => setState(() {
                    _needs2fa = false;
                    _totp.clear();
                    _error = null;
                  }),
                  child: const Text('Use a different account'),
                ),
              const SizedBox(height: Spacing.lg),
              if (!_needs2fa)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('New to TruERP?', style: context.text.bodyMedium),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              const SizedBox(height: Spacing.sm),
              Center(
                child: TextButton.icon(
                  onPressed: () => showServerSheet(context, ref),
                  icon: const Icon(Icons.dns_outlined, size: 18),
                  label: const Text('Server settings'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
