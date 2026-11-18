import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/card_payment.dart';
import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/features/credit_cards/card_debt_validation_dialog.dart';
import 'package:perfinance/services/card_debt_reconciliation_service.dart';

import '../../helpers/db_helper.dart';

/// Dos pumps acotados: la animación de entrada/salida del diálogo.
/// No se usa pumpAndSettle porque el cursor/transición puede agendar frames
/// de forma continua en el entorno de test.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Abre el diálogo "Validar deuda" sobre un host real y entrega la decisión
/// resultante al callback cuando el diálogo se cierra.
Future<void> _pumpDialogHost(
  WidgetTester tester, {
  required double expectedDebt,
  required void Function(CardDebtValidationDecision?) onDecided,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final decision = await showCardDebtValidationDialog(
                  context: context,
                  expectedDebt: expectedDebt,
                );
                onDecided(decision);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await _settle(tester);
}

void main() {
  testWidgets(
      'deuda calculada 1000: escribir 0 ofrece "Registrar pago" por 1000',
      (tester) async {
    CardDebtValidationDecision? decision;
    await _pumpDialogHost(
      tester,
      expectedDebt: 1000,
      onDecided: (d) => decision = d,
    );

    // Estado inicial: la deuda ingresada coincide con la calculada.
    expect(find.text('Sin ajuste'), findsOneWidget);
    expect(find.text('Confirmar deuda'), findsOneWidget);

    // El usuario escribe el saldo real: 0. La UI debe reaccionar en vivo.
    await tester.enterText(find.byType(CurrencyTextField), '0');
    await tester.pump();

    expect(find.text('Pago a registrar'), findsOneWidget);
    expect(find.text('Registrar pago'), findsOneWidget);
    expect(
      find.text(
        'La deuda real es menor que la calculada. Se registrará un pago de tarjeta por la diferencia.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Registrar pago'));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(decision, isNotNull);
    expect(decision!.actualDebt, 0);
    expect(decision!.reconciliation.action, CardDebtAdjustmentAction.cardPayment);
    expect(decision!.reconciliation.delta, 1000);
  });

  testWidgets('deuda real mayor que la calculada ofrece "Agregar faltante"',
      (tester) async {
    CardDebtValidationDecision? decision;
    await _pumpDialogHost(
      tester,
      expectedDebt: 1000,
      onDecided: (d) => decision = d,
    );

    await tester.enterText(find.byType(CurrencyTextField), '2000');
    await tester.pump();

    expect(find.text('Faltante detectado'), findsOneWidget);
    expect(find.text('Agregar faltante'), findsOneWidget);
    expect(
      find.text(
        'La deuda real es mayor que la calculada. Se agregará un egreso extra con la descripción Faltante de deuda.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Agregar faltante'));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(decision!.actualDebt, 2000);
    expect(decision!.reconciliation.action, CardDebtAdjustmentAction.missingExpense);
    expect(decision!.reconciliation.delta, 1000);
  });

  testWidgets('monto igual a la calculada: "Confirmar deuda" no genera movimientos',
      (tester) async {
    CardDebtValidationDecision? decision;
    await _pumpDialogHost(
      tester,
      expectedDebt: 1000,
      onDecided: (d) => decision = d,
    );

    await tester.tap(find.text('Confirmar deuda'));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(decision, isNotNull);
    expect(decision!.reconciliation.action, CardDebtAdjustmentAction.none);
    expect(decision!.reconciliation.delta, 0);
  });

  testWidgets('cancelar no devuelve decisión', (tester) async {
    CardDebtValidationDecision? decision;
    await _pumpDialogHost(
      tester,
      expectedDebt: 1000,
      onDecided: (d) => decision = d,
    );

    await tester.tap(find.text('Cancelar'));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(decision, isNull);
  });

  // Persistencia: mismo paso que _validateCurrentDebt al aceptar el pago.
  // Va en un test() plano: sqflite_common_ffi usa un isolate real y dentro de
  // testWidgets el reloj de fake-async lo deja esperando para siempre.
  test('el pago por la diferencia se persiste como pending_insert', () async {
    final db = await openTestDatabase();
    addTearDown(() => db.close());
    await db.insert(tableCreditCards, {
      'id': 'card-1',
      'user_id': 'user-1',
      'alias': 'Visa',
      'cut_off_day': 10,
      'management_fee': 0,
      'is_active': 1,
      columnSyncStatus: 'synced',
    });

    final payRepo = CardPaymentRepository(null, dbOverride: db);
    await payRepo.insert(
      CardPayment(
        id: 'uuid-1',
        cardId: 'card-1',
        amount: 1000,
        date: DateTime.now(),
      ),
    );

    final rows = await db.query(tableCardPayments);
    expect(rows.length, 1);
    expect(rows.first['amount'], 1000.0);
    expect(rows.first[columnSyncStatus], 'pending_insert');
  });
}
