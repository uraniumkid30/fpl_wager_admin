import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/features/auth/presentation/auth_controller.dart';

/// Administrator sign-in: email and password.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: GradientPanel(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: BrandMark(),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Admin sign in',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'For FPLboardman administrators only.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 26),
                        TextFormField(
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) =>
                              (value ?? '').trim().contains('@')
                                  ? null
                                  : 'Enter your email address',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          enabled: !_busy,
                          obscureText: !_showPassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _showPassword
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => (value ?? '').isEmpty
                              ? 'Enter your password'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success the router sees the new session and opens the dashboard.
      await ref
          .read(authControllerProvider.notifier)
          .login(_email.text.trim(), _password.text);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }
}
