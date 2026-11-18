import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/credit_card.dart';

/// Activas primero; dentro de cada grupo se respeta el orden original.
List<CreditCard> sortCardsActiveFirst(List<CreditCard> cards) {
  return [
    for (final card in cards)
      if (card.isActive) card,
    for (final card in cards)
      if (!card.isActive) card,
  ];
}

/// Línea de estado bajo el alias en la lista de tarjetas. Las desactivadas
/// lo dicen primero para que no se confundan con las que se pueden usar.
String cardStatusLine(CreditCard card, {required bool hideValues}) {
  final details = 'Corte el día ${card.cutOffDay} · Cuota \$${formatCurrencyDisplay(card.managementFee, hideValues)}';
  return card.isActive ? details : 'Desactivada · $details';
}
