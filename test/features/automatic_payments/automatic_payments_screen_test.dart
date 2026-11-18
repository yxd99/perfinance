import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payment_form_screen.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_screen.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/widgets/account_note_chip.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

AutomaticPayment _payment({required String id, required String description, String status = 'active'}) =>
    AutomaticPayment(
      id: id,
      userId: 'u1',
      paymentType: 'credit_card',
      paymentRef: 'card-1',
      amount: 45000,
      description: description,
      nextRunDate: DateTime(2026, 12, 15),
      paymentDayOfMonth: 15,
      status: status,
    );

Widget _build(List<AutomaticPayment> list) => ProviderScope(
  overrides: [
    automaticPaymentsListProvider.overrideWith((ref) async => list),
    expensePaymentDisplayProvider.overrideWith(
      (ref) async => const ExpensePaymentDisplay(cardAliases: {'card-1': 'Visa'}, methodNames: {}),
    ),
    accountHueSlotsProvider.overrideWith((ref) async => {'card-1': 0}),
    activeCreditCardsListProvider.overrideWith((ref) async => const []),
    paymentMethodsListProvider.overrideWith((ref) async => const []),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: AutomaticPaymentsScreen()),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pago activo: línea con día, frecuencia y cuenta, y billete de la cuenta', (tester) async {
    await tester.pumpWidget(_build([_payment(id: 'a1', description: 'Netflix')]));
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Día 15 · Mensual · Visa'), findsOneWidget);
    expect(find.text('\$45.000'), findsOneWidget);
    expect(find.byType(AccountNoteChip), findsOneWidget);
  });

  testWidgets('pago en pausa muestra "En pausa" en la línea de estado', (tester) async {
    await tester.pumpWidget(_build([_payment(id: 'a2', description: 'Gimnasio', status: 'paused')]));
    await tester.pumpAndSettle();

    expect(find.text('En pausa · Día 15 · Mensual · Visa'), findsOneWidget);
  });

  testWidgets('lista vacía explica qué hace un pago automático', (tester) async {
    await tester.pumpWidget(_build(const []));
    await tester.pumpAndSettle();

    expect(find.textContaining('Todavía no tenés pagos automáticos'), findsOneWidget);
    expect(find.text('Agregar pago automático'), findsOneWidget);
  });

  testWidgets('tocar un pago abre su formulario de edición', (tester) async {
    await tester.pumpWidget(_build([_payment(id: 'a1', description: 'Netflix')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Netflix'));
    await tester.pumpAndSettle();
    expect(find.byType(AutomaticPaymentFormScreen), findsOneWidget);
    expect(find.text('Editar pago automático'), findsOneWidget);
  });

  testWidgets('deslizar a la izquierda pide confirmar; mantener presionado no borra', (tester) async {
    await tester.pumpWidget(_build([_payment(id: 'a1', description: 'Netflix')]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mantené presionado'), findsNothing);

    // Mantener presionado no tiene un significado oculto.
    final inkWell = tester.widget<InkWell>(find.ancestor(of: find.text('Netflix'), matching: find.byType(InkWell)).first);
    expect(inkWell.onLongPress, isNull);

    expect(find.byType(Dismissible), findsOneWidget);
    await tester.drag(find.text('Netflix'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar pago automático'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsOneWidget);
  });
}
