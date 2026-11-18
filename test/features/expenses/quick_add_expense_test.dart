import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/quick_add_expense.dart';
import 'package:perfinance/features/savings/savings_provider.dart';

void main() {
  testWidgets('el «+» abre la hoja de registro y valida monto y cuenta', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expensesListProvider.overrideWith((ref) async => []),
          activeCreditCardsListProvider.overrideWith((ref) async => []),
          paymentMethodsListProvider.overrideWith((ref) async => []),
          expensePaymentDisplayProvider.overrideWith(
            (ref) async => const ExpensePaymentDisplay(cardAliases: {}, methodNames: {}),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showQuickAddExpense(context, ref),
                child: const Text('+'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Registrá un egreso'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);

    await tester.tap(find.text('Guardar egreso'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresá el monto'), findsOneWidget);
    expect(find.text('Elegí una tarjeta o cuenta'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}
