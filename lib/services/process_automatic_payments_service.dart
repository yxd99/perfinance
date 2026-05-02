import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:uuid/uuid.dart';

final processAutomaticPaymentsServiceProvider = Provider<ProcessAutomaticPaymentsService>((ref) {
  return ProcessAutomaticPaymentsService(ref);
});

class ProcessAutomaticPaymentsService {
  ProcessAutomaticPaymentsService(this._ref);
  final Ref _ref;

  static const String _expenseDescriptionPrefix = '[Pago automático]: ';

  /// Procesa los pagos automáticos vencidos: crea el egreso y avanza la fecha al mes siguiente.
  Future<void> run() async {
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return;

    final autoRepo = _ref.read(automaticPaymentRepositoryProvider);
    final expenseRepo = _ref.read(expenseRepositoryProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final due = await autoRepo.getDue(user.id, today);
    for (final p in due) {
      final expenseDate = DateTime(p.nextRunDate.year, p.nextRunDate.month, p.nextRunDate.day);
      // Deterministic UUID: same payment + same date → same id → idempotent on retry
      final expenseId = const Uuid().v5(Uuid.NAMESPACE_OID, '${p.id}:${expenseDate.toIso8601String()}');
      final nextRun = _nextMonthSameDay(p.nextRunDate);
      await expenseRepo.insert(Expense(
        id: expenseId,
        userId: user.id,
        amount: p.amount,
        date: expenseDate,
        paymentType: p.paymentType,
        paymentRef: p.paymentRef,
        description: '$_expenseDescriptionPrefix${p.description}',
      ));
      await autoRepo.updateNextRunDate(p.id, nextRun);
    }
  }

  static DateTime _nextMonthSameDay(DateTime d) {
    final nextMonth = d.month == 12 ? DateTime(d.year + 1, 1, 1) : DateTime(d.year, d.month + 1, 1);
    final lastDayOfNext = DateTime(nextMonth.year, nextMonth.month + 1, 0);
    final day = d.day <= lastDayOfNext.day ? d.day : lastDayOfNext.day;
    return DateTime(nextMonth.year, nextMonth.month, day);
  }
}
