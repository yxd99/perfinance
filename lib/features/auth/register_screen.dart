import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perfinance/core/widgets/brand_logo.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/auth/auth_copy.dart';
import 'package:perfinance/features/auth/auth_service.dart';
import 'package:perfinance/features/auth/auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
      await auth.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) context.go('/');
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AuthCopy.errorMessage(e, isLogin: false);
          _isLoading = false;
        });
      }
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'auth.sign_up');
      if (mounted) {
        setState(() {
          _errorMessage = AuthCopy.registerFailed;
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Crear cuenta')),
      body: AuthCanvas(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                            child: BrandLogo(height: 44),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Correo'),
                          validator: AuthCopy.validateEmail,
                        ),
                        const SizedBox(height: 12),
                        PasswordField(
                          controller: _passwordController,
                          label: 'Contraseña',
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (v) {
                            if (v == null || v.isEmpty) return AuthCopy.newPasswordRequired;
                            if (v.length < 6) return AuthCopy.passwordTooShort;
                            return null;
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                          child: Text('Al menos 6 caracteres.', style: t.bodySmall?.copyWith(color: c.textMuted)),
                        ),
                        const SizedBox(height: 12),
                        PasswordField(
                          controller: _confirmController,
                          label: 'Repite la contraseña',
                          autofillHints: const [AutofillHints.newPassword],
                          onSubmitted: _submit,
                          validator: (v) => v != _passwordController.text ? AuthCopy.passwordMismatch : null,
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          AuthErrorText(_errorMessage!),
                        ],
                        const SizedBox(height: 24),
                        AuthPrimaryButton(label: 'Crear cuenta', loading: _isLoading, onPressed: _submit),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isLoading ? null : () => context.pop(),
                          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                          child: Text.rich(
                            TextSpan(
                              text: '¿Ya tienes cuenta? ',
                              style: TextStyle(color: c.textMuted),
                              children: [
                                TextSpan(
                                  text: 'Inicia sesión',
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
