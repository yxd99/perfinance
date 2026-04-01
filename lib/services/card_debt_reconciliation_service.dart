import 'package:perfinance/data/models/card_payment.dart';
import 'package:perfinance/data/models/expense.dart';

enum CardDebtAdjustmentAction {
  none,
  missingExpense,
  cardPayment,
}

class CardDebtReconciliationResult {
  const CardDebtReconciliationResult({
    required this.expectedDebt,
    required this.actualDebt,
    required this.delta,
    required this.action,
  });

  final double expectedDebt;
  final double actualDebt;
  final double delta;
  final CardDebtAdjustmentAction action;
}

class CardDebtReconciliationService {
  static double currentDebtForCard({
    required String cardId,
    required List<Expense> expenses,
    required List<CardPayment> payments,
  }) {
    final spent = expenses
        .where((expense) => expense.paymentType == 'credit_card' && expense.paymentRef == cardId)
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    final paid = payments
        .where((payment) => payment.cardId == cardId)
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    return spent - paid;
  }

  static double projectedDebt({
    required double currentDebt,
    required double newExpenseAmount,
    double existingExpenseAmount = 0,
  }) {
    return currentDebt - existingExpenseAmount + newExpenseAmount;
  }

  static double projectedDebtForCard({
    required String cardId,
    required List<Expense> expenses,
    required List<CardPayment> payments,
    required double newExpenseAmount,
    required String newPaymentType,
    required String newPaymentRef,
    Expense? existingExpense,
  }) {
    final currentDebt = currentDebtForCard(
      cardId: cardId,
      expenses: expenses,
      payments: payments,
    );
    final double existingAmountForCard = existingExpense != null &&
            existingExpense.paymentType == 'credit_card' &&
            existingExpense.paymentRef == cardId
        ? existingExpense.amount
        : 0;
    final double newAmountForCard = newPaymentType == 'credit_card' && newPaymentRef == cardId
        ? newExpenseAmount
        : 0;
    return projectedDebt(
      currentDebt: currentDebt,
      newExpenseAmount: newAmountForCard,
      existingExpenseAmount: existingAmountForCard,
    );
  }

  static CardDebtReconciliationResult reconcile({
    required double expectedDebt,
    required double actualDebt,
  }) {
    final delta = (actualDebt - expectedDebt).abs();
    if (actualDebt > expectedDebt) {
      return CardDebtReconciliationResult(
        expectedDebt: expectedDebt,
        actualDebt: actualDebt,
        delta: delta,
        action: CardDebtAdjustmentAction.missingExpense,
      );
    }
    if (actualDebt < expectedDebt) {
      return CardDebtReconciliationResult(
        expectedDebt: expectedDebt,
        actualDebt: actualDebt,
        delta: delta,
        action: CardDebtAdjustmentAction.cardPayment,
      );
    }
    return CardDebtReconciliationResult(
      expectedDebt: expectedDebt,
      actualDebt: actualDebt,
      delta: 0,
      action: CardDebtAdjustmentAction.none,
    );
  }
}
