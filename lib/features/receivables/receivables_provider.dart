import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';

enum ReceivableListFilter { active, settled, all }

class ReceivableView {
  const ReceivableView({required this.receivable, required this.payments});

  final Receivable receivable;
  final List<ReceivablePayment> payments;

  double get totalPaid => payments.fold(0.0, (s, p) => s + p.amount);
  double get remainingBalance => receivable.totalAmount - totalPaid;
  bool get isFullyPaid => remainingBalance <= 0;
}

final receivablesListProvider = FutureProvider<List<Receivable>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  return ref.read(receivableRepositoryProvider).getAll(user.id);
});

final filteredReceivablesProvider =
    FutureProvider.family<List<ReceivableView>, ReceivableListFilter>(
  (ref, filter) async {
    // Watching receivablesListProvider so invalidating it cascades here.
    final all = await ref.watch(receivablesListProvider.future);
    final payRepo = ref.read(receivablePaymentRepositoryProvider);

    final List<Receivable> receivables;
    switch (filter) {
      case ReceivableListFilter.active:
        receivables = all.where((r) => r.status == ReceivableStatus.active).toList();
      case ReceivableListFilter.settled:
        receivables = all.where((r) => r.status == ReceivableStatus.settled).toList();
      case ReceivableListFilter.all:
        receivables = all
            .where((r) =>
                r.status != ReceivableStatus.hidden &&
                r.status != ReceivableStatus.writtenOff)
            .toList();
    }

    final views = <ReceivableView>[];
    for (final r in receivables) {
      final payments = await payRepo.getByReceivableId(r.id);
      views.add(ReceivableView(receivable: r, payments: payments));
    }
    return views;
  },
);

final receivablePaymentsProvider =
    FutureProvider.family<List<ReceivablePayment>, String>(
  (ref, receivableId) async {
    return ref.read(receivablePaymentRepositoryProvider).getByReceivableId(receivableId);
  },
);

final receivablesTotalOutstandingProvider = FutureProvider<double>((ref) async {
  // Watching receivablesListProvider so invalidating it cascades here.
  final all = await ref.watch(receivablesListProvider.future);
  final payRepo = ref.read(receivablePaymentRepositoryProvider);

  final active = all.where((r) => r.status == ReceivableStatus.active);
  var total = 0.0;
  for (final r in active) {
    final payments = await payRepo.getByReceivableId(r.id);
    final paid = payments.fold(0.0, (s, p) => s + p.amount);
    final remaining = (r.totalAmount - paid).clamp(0.0, double.infinity);
    total += remaining;
  }
  return total;
});
