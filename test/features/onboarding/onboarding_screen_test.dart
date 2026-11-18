import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('avanza por las tres páginas hasta «Empezar»', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(theme: AppTheme.light, home: const OnboardingScreen())),
    );
    expect(find.text('Tu mes en un vistazo'), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Registrá en segundos'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Empezar'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 3 de 3'), findsOneWidget);
  });
}
