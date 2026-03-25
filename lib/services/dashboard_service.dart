import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/data/repositories/debt_payment_repository.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';

class CardUsage {
  final String cardId;
  final String alias;
  final int count;
  final double totalAmount;

  CardUsage({required this.cardId, required this.alias, required this.count, required this.totalAmount});
}

class CardComparison {
  final String cardId;
  final String alias;
  final double lastMonth;
  final double thisMonth;
  final bool isIncrease;
  final double percentChange;

  CardComparison({
    required this.cardId,
    required this.alias,
    required this.lastMonth,
    required this.thisMonth,
    required this.isIncrease,
    required this.percentChange,
  });
}

class DashboardService {
  static Future<double> totalDebt(
    CreditCardRepository cardRepo,
    ExpenseRepository expenseRepo,
    CardPaymentRepository paymentRepo,
    DebtRepository debtRepo,
    DebtPaymentRepository debtPayRepo,
    String userId, {
    DateTime? asOfEndOfMonth,
  }) async {
    final cutoff = asOfEndOfMonth != null
        ? (asOfEndOfMonth.month == 12
            ? DateTime(asOfEndOfMonth.year + 1, 1, 1)
            : DateTime(asOfEndOfMonth.year, asOfEndOfMonth.month + 1, 1))
        : null;
    double total = 0;
    final cards = await cardRepo.getAll(userId);
    for (final c in cards) {
      var expenses = (await expenseRepo.getAll(userId)).where((e) => e.paymentType == 'credit_card' && e.paymentRef == c.id);
      if (cutoff != null) expenses = expenses.where((e) => e.date.isBefore(cutoff));
      final spent = expenses.fold<double>(0, (s, e) => s + e.amount);
      var payments = await paymentRepo.getByCardId(c.id);
      if (cutoff != null) payments = payments.where((p) => p.date.isBefore(cutoff)).toList();
      final paid = payments.fold<double>(0, (s, p) => s + p.amount);
      total += (spent - paid);
    }
    var debts = await debtRepo.getAll(userId);
    if (cutoff != null) debts = debts.where((d) => (d.createdAt != null && DateTime.parse(d.createdAt!).isBefore(cutoff)) || d.createdAt == null).toList();
    for (final d in debts) {
      var payments = await debtPayRepo.getByDebtId(d.id);
      if (cutoff != null) payments = payments.where((p) => p.date.isBefore(cutoff)).toList();
      final paid = payments.fold<double>(0, (s, p) => s + p.amount);
      total += (d.totalAmount - paid);
    }
    return total;
  }

  /// Indica si el usuario tiene fuentes de deuda activas (tarjetas o deudas a cuotas)
  /// hasta la fecha dada, para decidir si mostrar la sección Deuda total.
  static Future<bool> hasActiveDebtSources(
    CreditCardRepository cardRepo,
    DebtRepository debtRepo,
    String userId, {
    DateTime? asOfEndOfMonth,
  }) async {
    final cutoff = asOfEndOfMonth != null
        ? (asOfEndOfMonth.month == 12
            ? DateTime(asOfEndOfMonth.year + 1, 1, 1)
            : DateTime(asOfEndOfMonth.year, asOfEndOfMonth.month + 1, 1))
        : null;
    final cards = await cardRepo.getAll(userId);
    if (cards.isNotEmpty) return true;
    var debts = await debtRepo.getAll(userId);
    if (cutoff != null) debts = debts.where((d) => (d.createdAt != null && DateTime.parse(d.createdAt!).isBefore(cutoff)) || d.createdAt == null).toList();
    return debts.isNotEmpty;
  }

  static Future<List<CardUsage>> usagePerCard(
    CreditCardRepository cardRepo,
    ExpenseRepository expenseRepo,
    String userId, {
    DateTime? forMonth,
  }) async {
    final cards = await cardRepo.getAll(userId);
    var expenses = await expenseRepo.getAll(userId);
    if (forMonth != null) {
      final start = DateTime(forMonth.year, forMonth.month, 1);
      final end = forMonth.month == 12 ? DateTime(forMonth.year + 1, 1, 1) : DateTime(forMonth.year, forMonth.month + 1, 1);
      expenses = expenses.where((e) => !e.date.isBefore(start) && e.date.isBefore(end)).toList();
    }
    final byCard = <String, List<Expense>>{};
    for (final e in expenses) {
      if (e.paymentType != 'credit_card') continue;
      byCard.putIfAbsent(e.paymentRef, () => []).add(e);
    }
    return cards.map((c) {
      final list = byCard[c.id] ?? [];
      return CardUsage(
        cardId: c.id,
        alias: c.alias,
        count: list.length,
        totalAmount: list.fold(0.0, (s, e) => s + e.amount),
      );
    }).toList();
  }

  static Future<List<CardComparison>> comparisonPerCard(
    CreditCardRepository cardRepo,
    ExpenseRepository expenseRepo,
    String userId, {
    DateTime? forMonth,
  }) async {
    final cards = await cardRepo.getAll(userId);
    final expenses = await expenseRepo.getAll(userId);
    final ref = forMonth ?? DateTime.now();
    final thisMonthStart = DateTime(ref.year, ref.month, 1);
    final thisMonthEnd = ref.month == 12 ? DateTime(ref.year + 1, 1, 1) : DateTime(ref.year, ref.month + 1, 1);
    final lastMonthStart = ref.month == 1 ? DateTime(ref.year - 1, 12, 1) : DateTime(ref.year, ref.month - 1, 1);
    final lastMonthEnd = thisMonthStart;
    return cards.map((c) {
      final thisMonth = expenses
          .where((e) => e.paymentType == 'credit_card' && e.paymentRef == c.id && !e.date.isBefore(thisMonthStart) && e.date.isBefore(thisMonthEnd))
          .fold<double>(0, (s, e) => s + e.amount);
      final lastMonth = expenses
          .where((e) => e.paymentType == 'credit_card' && e.paymentRef == c.id && !e.date.isBefore(lastMonthStart) && e.date.isBefore(lastMonthEnd))
          .fold<double>(0, (s, e) => s + e.amount);
      final isIncrease = thisMonth > lastMonth;
      final den = lastMonth > 0 ? lastMonth : 1;
      final percentChange = ((thisMonth - lastMonth) / den * 100).abs();
      return CardComparison(
        cardId: c.id,
        alias: c.alias,
        lastMonth: lastMonth,
        thisMonth: thisMonth,
        isIncrease: isIncrease,
        percentChange: percentChange,
      );
    }).toList();
  }
}
