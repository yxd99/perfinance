import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/data/repositories/debt_payment_repository.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/data/repositories/min_payment_config_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/core/utils/date_utils.dart';
import 'package:perfinance/services/dashboard_service.dart';

/// Mes seleccionado para consultar en el dashboard (solo año y mes se usan).
final selectedDashboardMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final dashboardDebtProvider = FutureProvider.autoDispose<DebtBreakdown>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return const DebtBreakdown(total: 0, items: []);
  final month = ref.watch(selectedDashboardMonthProvider);
  final cardRepo = ref.read(creditCardRepositoryProvider);
  final expenseRepo = ref.read(expenseRepositoryProvider);
  final payRepo = ref.read(cardPaymentRepositoryProvider);
  final debtRepo = ref.read(debtRepositoryProvider);
  final debtPayRepo = ref.read(debtPaymentRepositoryProvider);
  // DashboardService solo usa año y mes de asOfEndOfMonth: corta en el día 1 del
  // mes siguiente (exclusivo). Pasar el día 1 del mes elegido es correcto, no un bug.
  final asOfEndOfMonth = DateTime(month.year, month.month, 1);
  return DashboardService.debtBreakdown(
    cardRepo,
    expenseRepo,
    payRepo,
    debtRepo,
    debtPayRepo,
    user.id,
    asOfEndOfMonth: asOfEndOfMonth,
  );
});

/// True si el usuario tiene fuentes de deuda (tarjetas o deudas a cuotas) para el mes seleccionado.
final hasActiveDebtSourcesProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return false;
  final month = ref.watch(selectedDashboardMonthProvider);
  final cardRepo = ref.read(creditCardRepositoryProvider);
  final debtRepo = ref.read(debtRepositoryProvider);
  final asOfEndOfMonth = DateTime(month.year, month.month, 1);
  return DashboardService.hasActiveDebtSources(
    cardRepo,
    debtRepo,
    user.id,
    asOfEndOfMonth: asOfEndOfMonth,
  );
});

final dashboardUsageProvider = FutureProvider.autoDispose<List<CardUsage>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  final month = ref.watch(selectedDashboardMonthProvider);
  final cardRepo = ref.read(creditCardRepositoryProvider);
  final expenseRepo = ref.read(expenseRepositoryProvider);
  return DashboardService.usagePerCard(cardRepo, expenseRepo, user.id, forMonth: month);
});

final dashboardComparisonProvider = FutureProvider.autoDispose<List<CardComparison>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  final month = ref.watch(selectedDashboardMonthProvider);
  final cardRepo = ref.read(creditCardRepositoryProvider);
  final expenseRepo = ref.read(expenseRepositoryProvider);
  return DashboardService.comparisonPerCard(cardRepo, expenseRepo, user.id, forMonth: month);
});

/// Total de pago mínimo pendiente y por tarjeta para el mes seleccionado.
/// pendingByCard solo incluye tarjetas con pendiente > 0.
final dashboardMinPaymentSummaryProvider = FutureProvider.autoDispose<DashboardMinPaymentSummary>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return DashboardMinPaymentSummary(totalPending: 0, pendingByCard: {});
  final month = ref.watch(selectedDashboardMonthProvider);
  final cardRepo = ref.read(creditCardRepositoryProvider);
  final configRepo = ref.read(minPaymentConfigRepositoryProvider);
  final paymentRepo = ref.read(cardPaymentRepositoryProvider);
  final cards = await cardRepo.getAll(user.id, includeInactive: true);
  double totalPending = 0;
  final pendingByCard = <String, double>{};
  for (final c in cards) {
    final config = await configRepo.getForCardAndMonth(c.id, month.year, month.month);
    if (config == null) continue;
    final payments = await paymentRepo.getByCardIdInMonth(c.id, month.year, month.month);
    final clampedDay = clampEffectiveDay(config.effectiveDay, month.year, month.month);
    final cutoff = DateTime(month.year, month.month, clampedDay);
    final paid = payments
        .where((p) => !p.date.isBefore(cutoff))
        .fold<double>(0, (s, p) => s + p.amount);
    final pending = (config.amount - paid).clamp(0.0, double.infinity);
    if (pending > 0) {
      totalPending += pending;
      pendingByCard[c.id] = pending;
    }
  }
  return DashboardMinPaymentSummary(totalPending: totalPending, pendingByCard: pendingByCard);
});

class DashboardMinPaymentSummary {
  const DashboardMinPaymentSummary({
    required this.totalPending,
    required this.pendingByCard,
  });
  final double totalPending;
  final Map<String, double> pendingByCard;
}
