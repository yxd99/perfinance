import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:uuid/uuid.dart';

final processAutomaticPaymentsServiceProvider = Provider<ProcessAutomaticPaymentsService>((ref) {
  return ProcessAutomaticPaymentsService(ref);
});

/// Calcula la próxima fecha de ejecución según la frecuencia y el día canónico de pago.
/// Clampea el día al último día válido del mes destino sin modificar [dayOfMonth].
DateTime nextRunDateFor({
  required String frequency,
  required int dayOfMonth,
  required DateTime from,
}) {
  final months = switch (frequency) {
    'trimestral' => 3,
    'semestral' => 6,
    'anual' => 12,
    _ => 1, // mensual default
  };
  final target = DateTime(from.year, from.month + months, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  final day = dayOfMonth > lastDay ? lastDay : dayOfMonth;
  return DateTime(target.year, target.month, day);
}

/// Ocurrencia anterior a [nextRunDate] según la frecuencia: la última fecha
/// ya cobrada, dado que tras procesarse el cron avanza next_run_date al
/// siguiente ciclo. Usada para saber si un pago ya se cobró este mes.
DateTime previousRunDateFor({
  required String frequency,
  required int dayOfMonth,
  required DateTime nextRunDate,
}) {
  final months = switch (frequency) {
    'trimestral' => 3,
    'semestral' => 6,
    'anual' => 12,
    _ => 1, // mensual default
  };
  final target = DateTime(nextRunDate.year, nextRunDate.month - months, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  final day = dayOfMonth > lastDay ? lastDay : dayOfMonth;
  return DateTime(target.year, target.month, day);
}

class ProcessAutomaticPaymentsService {
  ProcessAutomaticPaymentsService(this._ref);
  final Ref _ref;

  static const String _expenseDescriptionPrefix = '[Pago automático]: ';

  /// Procesa los pagos automáticos vencidos: crea el egreso y avanza la fecha según la frecuencia.
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
      final nextRun = nextRunDateFor(
        frequency: p.frequency,
        dayOfMonth: p.paymentDayOfMonth,
        from: p.nextRunDate,
      );
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
}
