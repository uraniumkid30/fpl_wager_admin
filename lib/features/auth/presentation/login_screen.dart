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
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: palette.page,
      body: Stack(
        children: [
          // Two soft glows in the brand colours behind the card.
          Positioned(
            top: -160,
            left: -120,
            child: _Glow(
              color: AppColors.emerald.withValues(alpha: dark ? 0.22 : 0.16),
              size: 460,
            ),
          ),
          Positioned(
            bottom: -180,
            right: -140,
            child: _Glow(
              color: AppColors.purple.withValues(alpha: dark ? 0.18 : 0.10),
              size: 520,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                // Centre stops the card being stretched to the screen's width.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: BrandMark()),
                        const SizedBox(height: 24),
                        _card(context, palette, theme),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 14, color: palette.muted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Administrators only. Sign-ins are recorded.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
                              ),
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
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Palette palette, ThemeData theme) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.35 : 0.08,
              ),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
          child: AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to the FPLboardman admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.muted),
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
                    validator: (value) => (value ?? '').trim().contains('@')
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
                        tooltip: _showPassword ? 'Hide password' : 'Show password',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) =>
                        (value ?? '').isEmpty ? 'Enter your password' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  AnimatedSize(
                    duration: AppMotion.standard,
                    alignment: Alignment.topCenter,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 18,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(color: theme.colorScheme.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(_busy ? 'Signing in…' : 'Sign in'),
                    ),
                  ),
                ],
              ),
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

/// A large, soft circle of colour, blurred into the background.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
          ),
        ),
      );
}
