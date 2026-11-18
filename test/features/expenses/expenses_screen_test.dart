import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/expenses/expense_date_filter.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/expenses_screen.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Expense _expense(String id, String? description) => Expense(
      id: id,
      userId: 'u1',
      amount: 12500,
      date: DateTime.now(),
      paymentType: 'payment_method',
      paymentRef: 'm1',
      description: description,
    );

Widget _app(List<Expense> all, List<Expense> filtered) => ProviderScope(
      overrides: [
        expensesListProvider.overrideWith((ref) async => all),
        filteredExpensesListProvider.overrideWith((ref) async => filtered),
        creditCardsListProvider.overrideWith((ref) async => []),
        paymentMethodsListProvider.overrideWith((ref) async => []),
        expensePaymentDisplayProvider.overrideWith(
          (ref) async => const ExpensePaymentDisplay(cardAliases: {}, methodNames: {'m1': 'Nequi'}),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: ExpensesScreen())),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('filtro vacío lo dice y ofrece ver el mes', (tester) async {
    await tester.pumpWidget(_app([_expense('a', 'Taxi')], []));
    await tester.pumpAndSettle();
    expect(find.text('Egresos'), findsWidgets);
    expect(find.text('Hoy no registraste egresos'), findsOneWidget);
    expect(find.text('No hay egresos registrados'), findsNothing);
    await tester.tap(find.text('Ver este mes'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(ExpensesScreen)));
    expect(container.read(selectedExpenseDateFilterProvider).type, ExpenseDateFilterType.currentMonth);
  });

  testWidgets('sin egresos en absoluto dice que no hay registrados', (tester) async {
    await tester.pumpWidget(_app([], []));
    await tester.pumpAndSettle();
    expect(find.text('No hay egresos registrados'), findsOneWidget);
  });

  testWidgets('fila de Wallet muestra el comercio sin prefijo, el marcador y el total', (tester) async {
    final e = _expense('a', '[Wallet]: Éxito');
    await tester.pumpWidget(_app([e], [e]));
    await tester.pumpAndSettle();
    expect(find.text('Éxito'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Nequi'), findsOneWidget);
    expect(find.text('Hoy'), findsWidgets);
    expect(find.byType(Dismissible), findsOneWidget);
  });
}
