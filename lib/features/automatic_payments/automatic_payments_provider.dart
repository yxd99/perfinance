import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/data/repositories/payment_method_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';

final automaticPaymentsListProvider = FutureProvider<List<AutomaticPayment>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  return ref.read(automaticPaymentRepositoryProvider).getAll(user.id);
});

/// Resumen de pagos automáticos por mes: total y desglose por tarjeta/medio usado.
class AutomaticPaymentsSummary {
  const AutomaticPaymentsSummary({required this.totalPerMonth, required this.byAccount});
  final double totalPerMonth;
  final List<AutomaticPaymentByAccount> byAccount;
}

class AutomaticPaymentByAccount {
  const AutomaticPaymentByAccount({
    required this.alias,
    required this.amount,
    required this.isCreditCard,
    required this.paymentRef,
    required this.paymentType,
  });
  final String alias;
  final double amount;
  final bool isCreditCard;
  final String paymentRef;
  final String paymentType; // 'credit_card' | 'payment_method'
}

final dashboardAutomaticPaymentsSummaryProvider = FutureProvider<AutomaticPaymentsSummary>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return const AutomaticPaymentsSummary(totalPerMonth: 0, byAccount: []);
  final list = await ref.watch(automaticPaymentsListProvider.future);
  if (list.isEmpty) return const AutomaticPaymentsSummary(totalPerMonth: 0, byAccount: []);

  final totalPerMonth = list.fold<double>(0, (s, p) => s + p.amount);

  final byRef = <String, double>{};
  final typeByRef = <String, String>{};
  for (final p in list) {
    final key = p.paymentRef;
    byRef[key] = (byRef[key] ?? 0) + p.amount;
    typeByRef[key] = p.paymentType;
  }

  final cardRepo = ref.read(creditCardRepositoryProvider);
  final methodRepo = ref.read(paymentMethodRepositoryProvider);
  final cards = await cardRepo.getAll(user.id, includeInactive: true);
  final methods = await methodRepo.getAll(user.id);

  final cardAlias = {for (final c in cards) c.id: c.alias};
  final methodAlias = {for (final m in methods) m.id: m.name};

  final byAccount = <AutomaticPaymentByAccount>[];
  for (final e in byRef.entries) {
    final refId = e.key;
    final amount = e.value;
    final type = typeByRef[refId] ?? 'payment_method';
    final isCreditCard = type == 'credit_card';
    final alias = isCreditCard ? (cardAlias[refId] ?? 'Tarjeta') : (methodAlias[refId] ?? 'Medio');
    byAccount.add(AutomaticPaymentByAccount(
      alias: alias,
      amount: amount,
      isCreditCard: isCreditCard,
      paymentRef: refId,
      paymentType: type,
    ));
  }
  byAccount.sort((a, b) => b.amount.compareTo(a.amount));

  return AutomaticPaymentsSummary(totalPerMonth: totalPerMonth, byAccount: byAccount);
});
