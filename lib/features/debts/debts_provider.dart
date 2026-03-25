import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/repositories/debt_payment_repository.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';

enum DebtListFilter { all, active, paid }

final debtListFilterProvider = StateProvider<DebtListFilter>((ref) => DebtListFilter.all);
final debtSearchQueryProvider = StateProvider<String>((ref) => '');

class DebtWithPaid {
  const DebtWithPaid({required this.debt, required this.paid});
  final Debt debt;
  final double paid;
  bool get isPaid => paid >= debt.totalAmount;
}

final debtsListProvider = FutureProvider.autoDispose<List<Debt>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  return ref.read(debtRepositoryProvider).getAll(user.id);
});

/// Lista de deudas con monto pagado, filtrada por tipo (todas/activas/pagadas) y búsqueda por nombre/descripción.
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
  if (filter == DebtListFilter.active) result = result.where((e) => !e.isPaid).toList();
  if (filter == DebtListFilter.paid) result = result.where((e) => e.isPaid).toList();
  if (query.isNotEmpty) {
    result = result.where((e) => e.debt.name.toLowerCase().contains(query)).toList();
  }
  return result;
});
