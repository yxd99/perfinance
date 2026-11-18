import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/onboarding/onboarding_screen.dart';
import 'package:perfinance/features/savings/savings_provider.dart';

/// Títulos de la guía, en orden: cubre cada sección de la app.
const _titles = [
  'Hola, esto es Perfinance',
  'Mes: cómo vas este mes',
  'Registra un egreso',
  'Egresos: todo lo que gastaste',
  'Tarjetas de crédito',
  'Cuentas de ahorro',
  'Deudas: lo que debes',
  'Me deben: lo que prestaste',
  'Auto-pagos',
  'Asesor, privacidad y respaldo',
  'Empieza por tus cuentas',
];

Widget _app(Widget home, {List<CreditCard> cards = const [], List<PaymentMethod> methods = const []}) => ProviderScope(
      overrides: [
        activeCreditCardsListProvider.overrideWith((ref) async => cards),
        paymentMethodsListProvider.overrideWith((ref) async => methods),
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

void main() {
  testWidgets('recorre toda la app paso a paso hasta armar las cuentas', (tester) async {
    await tester.pumpWidget(_app(const OnboardingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Omitir'), findsOneWidget);

    for (var i = 0; i < _titles.length; i++) {
      expect(find.text(_titles[i]), findsOneWidget, reason: _titles[i]);
      expect(find.bySemanticsLabel('Paso ${i + 1} de ${_titles.length}'), findsOneWidget);
      if (i < _titles.length - 1) {
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('Agregar tarjeta de crédito'), findsOneWidget);
    expect(find.text('Agregar cuenta de ahorro'), findsOneWidget);
    expect(find.text('Empezar a usar Perfinance'), findsOneWidget);
  });

  testWidgets('el primer paso dice que solo se registran egresos y cómo volver a la guía', (tester) async {
    await tester.pumpWidget(_app(const OnboardingScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('no ingresos'), findsOneWidget);
    expect(find.textContaining('Más › Guía de la app'), findsOneWidget);
  });

  testWidgets('«Atrás» vuelve al paso anterior', (tester) async {
    await tester.pumpWidget(_app(const OnboardingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Atrás'), findsNothing);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    expect(find.text(_titles.first), findsOneWidget);
  });

  testWidgets('el último paso cuenta las cuentas que ya tienes', (tester) async {
    await tester.pumpWidget(_app(
      const OnboardingScreen(initialStep: 10),
      cards: [CreditCard(id: 'c', userId: 'u', alias: 'Visa', cutOffDay: 15, managementFee: 0)],
      methods: [
        PaymentMethod(id: 'a', userId: 'u', name: 'Nequi', type: 'debito'),
        PaymentMethod(id: 'b', userId: 'u', name: 'Efectivo', type: 'cash'),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tienes 1 tarjeta de crédito'), findsOneWidget);
    expect(find.text('Tienes 2 cuentas de ahorro'), findsOneWidget);
  });

  testWidgets('desde «Más» la guía se cierra y vuelve a donde estabas', (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const OnboardingScreen(replay: true)),
        ),
        child: const Text('abrir guía'),
      ),
    )));
    await tester.tap(find.text('abrir guía'));
    await tester.pumpAndSettle();
    expect(find.text('Omitir'), findsNothing);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('abrir guía'), findsOneWidget);
  });
}
