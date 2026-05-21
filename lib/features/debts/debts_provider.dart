import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/repositories/debt_payment_repository.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';

enum DebtListFilter { active, paid, all, hidden }

enum DebtBadgeKind { none, paid, hidden }

final debtListFilterProvider = StateProvider<DebtListFilter>((ref) => DebtListFilter.active);
final debtSearchQueryProvider = StateProvider<String>((ref) => '');

class DebtWithPaid {
  const DebtWithPaid({required this.debt, required this.paid});
  final Debt debt;
  final double paid;

  bool get isPaid => debt.status == DebtStatus.paid;
  bool get isHidden => debt.status == DebtStatus.hidden;

  DebtBadgeKind get badgeKind {
    if (debt.status == DebtStatus.paid) return DebtBadgeKind.paid;
    if (debt.status == DebtStatus.hidden) return DebtBadgeKind.hidden;
    return DebtBadgeKind.none;
  }
}

final debtsListProvider = FutureProvider.autoDispose<List<Debt>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  return ref.read(debtRepositoryProvider).getAll(user.id);
});

/// Lista de deudas con monto pagado, filtrada y con búsqueda.
final filteredDebtsWithPaidProvider = FutureProvider.autoDispose<List<DebtWithPaid>>((ref) async {
  final list = await ref.watch(debtsListProvider.future);
  final filter = ref.watch(debtListFilterProvider);
  final query = ref.watch(debtSearchQueryProvider).trim().toLowerCase();
  final payRepo = ref.read(debtPaymentRepositoryProvider);
  final withPaid = <DebtWithPaid>[];
  for (final debt in list) {
    final paid = await payRepo.getTotalPaidByDebtId(debt.id);
    withPaid.add(DebtWithPaid(debt: debt, paid: paid));
  }
  var result = withPaid;
  switch (filter) {
    case DebtListFilter.active:
      result = result.where((e) => e.debt.status == DebtStatus.active).toList();
    case DebtListFilter.paid:
      result = result.where((e) => e.debt.status == DebtStatus.paid).toList();
    case DebtListFilter.hidden:
      result = result.where((e) => e.debt.status == DebtStatus.hidden).toList();
    case DebtListFilter.all:
      result = result.where((e) => e.debt.status != DebtStatus.hidden).toList();
  }
  if (query.isNotEmpty) {
    result = result.where((e) => e.debt.name.toLowerCase().contains(query)).toList();
  }
  return result;
});

/// Suma totalAmount solo para deudas activas. No depende del filtro de lista seleccionado.
final outstandingDebtsTotalProvider = FutureProvider.autoDispose<double>((ref) async {
  final debts = await ref.watch(debtsListProvider.future);
  final payRepo = ref.read(debtPaymentRepositoryProvider);
  var total = 0.0;
  for (final debt in debts.where((d) => d.status == DebtStatus.active)) {
    final paid = await payRepo.getTotalPaidByDebtId(debt.id);
    final remaining = (debt.totalAmount - paid).clamp(0.0, double.infinity);
    total += remaining;
  }
  return total;
});
