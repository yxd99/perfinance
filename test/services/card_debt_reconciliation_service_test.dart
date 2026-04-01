import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/card_payment.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/services/card_debt_reconciliation_service.dart';

void main() {
  group('CardDebtReconciliationService', () {
    test('calcula deuda actual usando egresos de tarjeta menos pagos', () {
      final debt = CardDebtReconciliationService.currentDebtForCard(
        cardId: 'card-1',
        expenses: [
          Expense(
            id: 'expense-1',
            userId: 'user-1',
            amount: 200000,
            date: DateTime(2026, 3, 1),
            paymentType: 'credit_card',
            paymentRef: 'card-1',
          ),
          Expense(
            id: 'expense-2',
            userId: 'user-1',
            amount: 50000,
            date: DateTime(2026, 3, 2),
            paymentType: 'payment_method',
            paymentRef: 'cash',
          ),
          Expense(
            id: 'expense-3',
            userId: 'user-1',
            amount: 300000,
            date: DateTime(2026, 3, 3),
            paymentType: 'credit_card',
            paymentRef: 'card-1',
          ),
        ],
        payments: [
          CardPayment(
            id: 'payment-1',
            cardId: 'card-1',
            amount: 120000,
            date: DateTime(2026, 3, 4),
          ),
          CardPayment(
            id: 'payment-2',
            cardId: 'card-2',
            amount: 999999,
            date: DateTime(2026, 3, 5),
          ),
        ],
      );

      expect(debt, 380000);
    });

    test('proyecta deuda al editar un egreso existente', () {
      final projectedDebt = CardDebtReconciliationService.projectedDebt(
        currentDebt: 500000,
        newExpenseAmount: 250000,
        existingExpenseAmount: 100000,
      );

      expect(projectedDebt, 650000);
    });

    test('crea ajuste como faltante cuando la deuda real es mayor', () {
      final result = CardDebtReconciliationService.reconcile(
        expectedDebt: 500000,
        actualDebt: 650000,
      );

      expect(result.action, CardDebtAdjustmentAction.missingExpense);
      expect(result.delta, 150000);
    });

    test('crea ajuste como pago cuando la deuda real es menor', () {
      final result = CardDebtReconciliationService.reconcile(
        expectedDebt: 500000,
        actualDebt: 400000,
      );

      expect(result.action, CardDebtAdjustmentAction.cardPayment);
      expect(result.delta, 100000);
    });

    test('no crea ajuste cuando la deuda real coincide', () {
      final result = CardDebtReconciliationService.reconcile(
        expectedDebt: 500000,
        actualDebt: 500000,
      );

      expect(result.action, CardDebtAdjustmentAction.none);
      expect(result.delta, 0);
    });
  });
}
