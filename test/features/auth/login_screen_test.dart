import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/auth/auth_copy.dart';
import 'package:perfinance/features/auth/login_screen.dart';

void main() {
  testWidgets('login en español neutro y validación sin llamar al servidor', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(theme: AppTheme.light, home: const LoginScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.text('Crea una', findRichText: true), findsNothing);
    expect(find.textContaining('¿No tienes cuenta?', findRichText: true), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text(AuthCopy.emailRequired), findsOneWidget);
    expect(find.text(AuthCopy.passwordRequired), findsOneWidget);
  });

  test('errores de auth en español neutro', () {
    expect(AuthCopy.errorMessage(Exception('Invalid login credentials'), isLogin: true), 'Correo o contraseña incorrectos.');
    expect(AuthCopy.errorMessage(Exception('SocketException'), isLogin: true), startsWith('Sin conexión. Revisa'));
    expect(AuthCopy.errorMessage(Exception('User already registered'), isLogin: false), contains('Inicia sesión'));
    expect(AuthCopy.errorMessage(Exception('???'), isLogin: true), AuthCopy.loginFailed);
  });
}
