import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_screen.dart';
import 'package:perfinance/features/dashboard/month_pace.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/services/dashboard_service.dart';

class _FakeHide extends HideValuesNotifier {
  _FakeHide(this.value);
  final bool value;
  @override
  Future<bool> build() async => value;
}

Future<void> _pump(
  WidgetTester tester, {
  bool hide = false,
  bool failExpenses = false,
  bool disableAnimations = true,
}) async {
  final now = DateTime.now();
  final month = DateTime(now.year, now.month, 1);
  final expenses = [
    Expense(id: '1', userId: 'u', amount: 120000, date: month, paymentType: 'credit_card', paymentRef: 'card-1'),
    Expense(id: '2', userId: 'u', amount: 30000, date: month, paymentType: 'payment_method', paymentRef: 'cash'),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hideValuesProvider.overrideWith(() => _FakeHide(hide)),
        expensesListProvider.overrideWith((ref) async {
          if (failExpenses) throw StateError('db');
          return expenses;
        }),
        expensePaymentDisplayProvider.overrideWith((ref) async =>
            const ExpensePaymentDisplay(cardAliases: {'card-1': 'Visa Bancolombia'}, methodNames: {'cash': 'Efectivo'})),
        creditCardsListProvider.overrideWith((ref) async => [
              CreditCard(id: 'card-1', userId: 'u', alias: 'Visa Bancolombia', cutOffDay: 40, managementFee: 0),
            ]),
        overdueAutomaticPaymentsProvider.overrideWith((ref) async => <AutomaticPayment>[]),
        dashboardMinPaymentSummaryProvider
            .overrideWith((ref) async => const DashboardMinPaymentSummary(totalPending: 0, pendingByCard: {})),
        hasActiveDebtSourcesProvider.overrideWith((ref) async => true),
        dashboardDebtProvider.overrideWith((ref) async => const DebtBreakdown(total: 500000, items: [])),
        dashboardAutomaticPaymentsSummaryProvider
            .overrideWith((ref) async => const AutomaticPaymentsSummary(totalPerMonth: 0, byAccount: [])),
        dashboardComparisonProvider.overrideWith((ref) async => <CardComparison>[]),
        dashboardUsageProvider.overrideWith((ref) async => <CardUsage>[]),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(size: const Size(390, 844), disableAnimations: disableAnimations),
          child: const Scaffold(body: DashboardScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra la nota del mes, la frase de ritmo y las cuentas', (tester) async {
    await _pump(tester);
    final now = DateTime.now();
    expect(find.text(monthNameEs(now.month)), findsOneWidget);
    expect(find.text('Gastado este mes'), findsOneWidget);
    expect(find.text('\$150.000'), findsOneWidget);
    expect(find.textContaining('para comparar'), findsOneWidget);
    expect(find.text('POR CUENTA'), findsOneWidget);
    expect(find.text('Visa Bancolombia'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('1 egreso'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ocultar valores enmascara el monto del mes y la deuda', (tester) async {
    await _pump(tester, hide: true);
    expect(find.text('\$150.000'), findsNothing);
    expect(find.text('\$500.000'), findsNothing);
    expect(find.text('\$••••••'), findsWidgets);
  });

  testWidgets('un error de carga se ve y ofrece reintentar', (tester) async {
    await _pump(tester, failExpenses: true);
    expect(find.text('No pudimos cargar esta sección'), findsWidgets);
    expect(find.text('Reintentar'), findsWidgets);
  });

  testWidgets('con animaciones permitidas el anillo se anima y termina', (tester) async {
    await _pump(tester, disableAnimations: false);
    expect(find.text('Gastado este mes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
