import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/data/repositories/min_payment_config_repository.dart';

class MinPaymentStatus {
  final double pending;

  MinPaymentStatus(this.pending);
}

class MinPaymentService {
  static Future<MinPaymentStatus?> getStatus(
    MinPaymentConfigRepository configRepo,
    CardPaymentRepository paymentRepo,
    String cardId,
  ) async {
    final now = DateTime.now();
    final config = await configRepo.getForCardAndMonth(cardId, now.year, now.month);
    if (config == null) return null;
    final payments = await paymentRepo.getByCardIdInMonth(cardId, now.year, now.month);
    final paid = payments.fold<double>(0, (s, p) => s + p.amount);
    final pending = (config.amount - paid).clamp(0.0, double.infinity);
    return MinPaymentStatus(pending);
  }
}
