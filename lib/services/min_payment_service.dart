import 'package:perfinance/core/utils/date_utils.dart';
import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/data/repositories/min_payment_config_repository.dart';

class MinPaymentStatus {
  final double configured;
  final double paid; // payments with date >= effectiveDay cutoff
  final double totalPaidMonth; // ALL payments this month (no filter)
  final double pending; // derived from paid, NOT totalPaidMonth

  MinPaymentStatus({
    required this.configured,
    required this.paid,
    required this.totalPaidMonth,
    required this.pending,
  });

  bool get isUpToDate => pending <= 0;
}

class MinPaymentService {
  static Future<MinPaymentStatus?> getStatus(
    MinPaymentConfigRepository configRepo,
    CardPaymentRepository paymentRepo,
    String cardId,
  ) async {
    final now = DateTime.now();
    final config =
        await configRepo.getForCardAndMonth(cardId, now.year, now.month);
    if (config == null) return null;

    final clampedDay =
        clampEffectiveDay(config.effectiveDay, now.year, now.month);
    final cutoff = DateTime(now.year, now.month, clampedDay);

    final payments =
        await paymentRepo.getByCardIdInMonth(cardId, now.year, now.month);

    double totalPaid = 0;
    double paidAfterCutoff = 0;
    for (final p in payments) {
      totalPaid += p.amount;
      if (!p.date.isBefore(cutoff)) paidAfterCutoff += p.amount;
    }

    final pending =
        (config.amount - paidAfterCutoff).clamp(0.0, double.infinity);

    return MinPaymentStatus(
      configured: config.amount,
      paid: paidAfterCutoff,
      totalPaidMonth: totalPaid,
      pending: pending,
    );
  }
}
