import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perfinance/core/widgets/brand_logo.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/auth/auth_copy.dart';
import 'package:perfinance/features/auth/auth_service.dart';
import 'package:perfinance/features/auth/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) context.go('/');
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AuthCopy.errorMessage(e, isLogin: true);
          _isLoading = false;
        });
      }
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'auth.sign_in');
      if (mounted) {
        setState(() {
          _errorMessage = AuthCopy.loginFailed;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.canvas,
      body: AuthCanvas(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: BrandLogo(height: 52),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Semantics(
                          header: true,
                          child: Text(
                            'Iniciá sesión',
                            style: t.headlineSmall?.copyWith(color: c.ink),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tus egresos, tarjetas y deudas, en tu teléfono y en la nube.',
                          style: t.bodyMedium?.copyWith(color: c.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email, AutofillHints.username],
                          decoration: const InputDecoration(labelText: 'Correo'),
                          validator: AuthCopy.validateEmail,
                        ),
                        const SizedBox(height: 12),
                        PasswordField(
                          controller: _passwordController,
                          label: 'Contraseña',
                          onSubmitted: _submit,
                          validator: (v) => v == null || v.isEmpty ? AuthCopy.passwordRequired : null,
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          AuthErrorText(_errorMessage!),
                        ],
                        const SizedBox(height: 24),
                        AuthPrimaryButton(label: 'Iniciar sesión', loading: _isLoading, onPressed: _submit),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isLoading ? null : () => context.push('/register'),
                          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                          child: Text.rich(
                            TextSpan(
                              text: '¿No tenés cuenta? ',
                              style: TextStyle(color: c.textMuted),
                              children: [
                                TextSpan(
                                  text: 'Creá una',
                                  style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
