import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_screen.dart';
import 'package:perfinance/services/dashboard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El resto del dashboard queda cargando: el test mira solo el cuadro de deuda.
List<Override> _overrides({
  required FutureOr<bool> Function() hasActive,
  required FutureOr<DebtBreakdown> Function() debt,
}) {
  return [
    creditCardsListProvider.overrideWith((ref) => Completer<Never>().future),
    hasActiveDebtSourcesProvider.overrideWith((ref) async => hasActive()),
    dashboardDebtProvider.overrideWith((ref) async => debt()),
    dashboardUsageProvider.overrideWith((ref) => Completer<Never>().future),
    dashboardComparisonProvider.overrideWith((ref) => Completer<Never>().future),
    dashboardMinPaymentSummaryProvider.overrideWith((ref) => Completer<Never>().future),
    overdueAutomaticPaymentsProvider.overrideWith((ref) => Completer<Never>().future),
    dashboardAutomaticPaymentsSummaryProvider.overrideWith((ref) => Completer<Never>().future),
  ];
}

Future<void> _pumpDashboard(WidgetTester tester, List<Override> overrides) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('si falla el cálculo de la deuda muestra un aviso con reintentar', (tester) async {
    var calls = 0;
    await _pumpDashboard(
      tester,
      _overrides(
        hasActive: () => true,
        debt: () {
          calls++;
          throw StateError('boom');
        },
      ),
    );

    expect(find.text('Deuda total'), findsOneWidget);
    expect(find.text(UserFriendlyErrors.dashboardDebtLoadFailed), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('si falla saber si hay deudas también muestra el aviso', (tester) async {
    await _pumpDashboard(
      tester,
      _overrides(
        hasActive: () => throw StateError('boom'),
        debt: () => const DebtBreakdown(total: 0, items: []),
      ),
    );

    expect(find.text(UserFriendlyErrors.dashboardDebtLoadFailed), findsOneWidget);
  });

  testWidgets('sin fuentes de deuda no muestra el cuadro', (tester) async {
    await _pumpDashboard(
      tester,
      _overrides(
        hasActive: () => false,
        debt: () => const DebtBreakdown(total: 0, items: []),
      ),
    );

    expect(find.text('Deuda total'), findsNothing);
    expect(find.text(UserFriendlyErrors.dashboardDebtLoadFailed), findsNothing);
  });

  testWidgets('con deuda calculada muestra el cuadro sin aviso', (tester) async {
    await _pumpDashboard(
      tester,
      _overrides(
        hasActive: () => true,
        debt: () => const DebtBreakdown(total: 1500, items: []),
      ),
    );

    expect(find.text('Deuda total'), findsWidgets);
    expect(find.text(UserFriendlyErrors.dashboardDebtLoadFailed), findsNothing);
  });
}
