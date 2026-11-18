import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/features/savings/savings_screen.dart';

Widget _app(Future<List<PaymentMethod>> Function() load) => ProviderScope(
      overrides: [
        paymentMethodsListProvider.overrideWith((ref) => load()),
        accountHueSlotsProvider.overrideWith((ref) async => const <String, int>{}),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: SavingsScreen())),
    );

void main() {
  testWidgets('muestra el tipo traducido, nunca el valor crudo', (tester) async {
    await tester.pumpWidget(_app(() async => [
          PaymentMethod(id: 'a', userId: 'u', name: 'Billetera', type: 'cash'),
          PaymentMethod(id: 'b', userId: 'u', name: 'Nequi', type: 'debito'),
        ]));
    await tester.pumpAndSettle();
    expect(find.text('Billetera'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Débito'), findsOneWidget);
    expect(find.text('cash'), findsNothing);
    expect(find.text('Agregar medio de pago'), findsOneWidget);
  });

  testWidgets('sin medios lo dice y ofrece agregar uno', (tester) async {
    await tester.pumpWidget(_app(() async => []));
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no tenés medios de pago'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Agregar medio de pago'), findsOneWidget);
  });

  testWidgets('si falla la carga muestra el error y reintenta', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(() async {
      calls++;
      if (calls == 1) throw Exception('db');
      return [PaymentMethod(id: 'a', userId: 'u', name: 'Billetera', type: 'other')];
    }));
    await tester.pumpAndSettle();
    expect(find.text('No se pudieron cargar los medios de pago.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Billetera'), findsOneWidget);
    expect(find.text('Otro'), findsOneWidget);
  });
}
