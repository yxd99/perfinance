import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';

/// Orquesta el toggle de activo/inactivo de una tarjeta y el efecto colateral
/// de pausar sus pagos automáticos ligados. La reactivación NO reactiva
/// automáticamente los pagos pausados (decisión manual del usuario, por diseño).
class CreditCardLifecycleService {
  static Future<void> setActive(
    CreditCardRepository cardRepo,
    AutomaticPaymentRepository autoPayRepo,
    String cardId,
    bool isActive,
  ) async {
    await cardRepo.setActive(cardId, isActive);
    if (!isActive) {
      await autoPayRepo.pauseAllForCard(cardId);
    }
  }
}
