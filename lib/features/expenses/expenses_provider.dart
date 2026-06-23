import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/data/repositories/payment_method_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/expenses/expense_date_filter.dart';
import 'package:perfinance/features/savings/savings_provider.dart';

/// Alias/nombres de tarjetas y medios de pago del usuario para mostrar en egresos.
class ExpensePaymentDisplay {
  const ExpensePaymentDisplay({required this.cardAliases, required this.methodNames});
  final Map<String, String> cardAliases;
  final Map<String, String> methodNames;

  String aliasFor(Expense e) {
    if (e.paymentType == 'credit_card') return cardAliases[e.paymentRef] ?? 'Tarjeta';
    return methodNames[e.paymentRef] ?? 'Medio';
  }
}

final expensePaymentDisplayProvider = FutureProvider<ExpensePaymentDisplay>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return const ExpensePaymentDisplay(cardAliases: {}, methodNames: {});
  final cards = await ref.read(creditCardRepositoryProvider).getAll(user.id);
  final methods = await ref.read(paymentMethodRepositoryProvider).getAll(user.id);
  return ExpensePaymentDisplay(
    cardAliases: {for (final c in cards) c.id: c.alias},
    methodNames: {for (final m in methods) m.id: m.name},
  );
});

final expensesListProvider = FutureProvider<List<Expense>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  return ref.read(expenseRepositoryProvider).getAll(user.id);
});

final selectedExpenseDateFilterProvider = StateProvider<ExpenseDateFilter>((ref) => ExpenseDateFilter.today);

/// IDs de tarjeta o cuenta de ahorro (`payment_ref`). Vacío = no filtrar por medio.
final selectedExpensePaymentIdsFilterProvider = StateProvider<Set<String>>((ref) => {});

final filteredExpensesListProvider = FutureProvider<List<Expense>>((ref) async {
  final list = await ref.watch(expensesListProvider.future);
  final filter = ref.watch(selectedExpenseDateFilterProvider);
  final range = filter.rangeOrNow;
  final paymentFilter = ref.watch(selectedExpensePaymentIdsFilterProvider);
  final cards = await ref.watch(creditCardsListProvider.future);
  final methods = await ref.watch(paymentMethodsListProvider.future);
  final validIds = {
    ...cards.map((c) => c.id),
    ...methods.map((m) => m.id),
  };
  final activePaymentFilter = paymentFilter.intersection(validIds);
  return list.where((e) {
    // Comparar por día natural en hora local para evitar que fechas en UTC
    // (p. ej. desde sync) aparezcan en el filtro del día anterior.
    final dLocal = e.date.toLocal();
    final expenseDay = DateTime(dLocal.year, dLocal.month, dLocal.day);
    final rangeStartDay = DateTime(range.start.year, range.start.month, range.start.day);
    final rangeEndDay = DateTime(range.end.year, range.end.month, range.end.day);
    if (expenseDay.isBefore(rangeStartDay) || expenseDay.isAfter(rangeEndDay)) return false;
    if (activePaymentFilter.isEmpty) return true;
    return (e.paymentType == 'credit_card' || e.paymentType == 'payment_method') &&
        activePaymentFilter.contains(e.paymentRef);
  }).toList();
});
