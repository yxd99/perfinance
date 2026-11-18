import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/theme/account_hues.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/savings/savings_provider.dart';

/// Posición en la paleta de billetes de cada tarjeta y medio de pago,
/// incluidas las tarjetas desactivadas para que no cambien de color.
final accountHueSlotsProvider = FutureProvider<Map<String, int>>((ref) async {
  final cards = await ref.watch(creditCardsListProvider.future);
  final methods = await ref.watch(paymentMethodsListProvider.future);
  return assignHueSlots([
    for (final card in cards) (id: card.id, createdAt: card.createdAt),
    for (final method in methods) (id: method.id, createdAt: method.createdAt),
  ]);
});

extension AccountHueRef on WidgetRef {
  /// Tono de billete de una cuenta. Mientras cargan las cuentas usa el tono por id.
  Color accountHue(BuildContext context, String id) {
    final slots = watch(accountHueSlotsProvider).valueOrNull ?? const <String, int>{};
    return context.colors.accountColorFor(id, slots);
  }
}
