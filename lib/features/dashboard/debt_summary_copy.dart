import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/services/dashboard_service.dart';

/// Línea bajo «Deuda total» en el Mes que explica la suma: deudas a cuotas más saldo
/// de tarjetas. Así no se confunde con «Total por pagar» de Deudas, que no incluye
/// tarjetas pero sí las deudas que otros registraron a tu nombre.
/// Solo nombra lo que tiene saldo; sin saldo devuelve null.
String? debtTotalParts(DebtBreakdown breakdown, {required bool hideValues}) {
  var debts = 0.0;
  var cards = 0.0;
  for (final item in breakdown.items) {
    if (item.isCreditCard) {
      cards += item.balance;
    } else {
      debts += item.balance;
    }
  }
  final parts = [
    if (debts > 0) 'Deudas \$${formatCurrencyDisplay(debts, hideValues)}',
    if (cards > 0) 'Tarjetas \$${formatCurrencyDisplay(cards, hideValues)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
