import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/app_empty_state.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/credit_cards/credit_card_detail_screen.dart';
import 'package:perfinance/features/credit_cards/credit_card_form_screen.dart';

class CreditCardsScreen extends ConsumerWidget {
  const CreditCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCards = ref.watch(creditCardsListProvider);
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    return asyncCards.when(
      data: (cards) {
        if (cards.isEmpty) {
          return AppEmptyState(
            icon: Icons.credit_card_outlined,
            message: 'No hay tarjetas. Añade una.',
            actionLabel: 'Añadir tarjeta',
            onAction: () => _openForm(context, ref),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cards.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton.icon(
                  onPressed: () => _openForm(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir tarjeta'),
                ),
              );
            }
            final card = cards[i - 1];
            return _CreditCardTile(
              card: card,
              hideValues: hideValues,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreditCardDetailScreen(cardId: card.id),
                ),
              ),
              onLongPress: () => _editCard(context, ref, card),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorState(
        message: UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.cardsLoadFailed),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreditCardFormScreen(),
      ),
    );
  }

  void _editCard(BuildContext context, WidgetRef ref, CreditCard card) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreditCardFormScreen(editCard: card),
      ),
    );
  }
}

class _CreditCardTile extends StatelessWidget {
  const _CreditCardTile({
    required this.card,
    required this.hideValues,
    required this.onTap,
    required this.onLongPress,
  });

  final CreditCard card;
  final bool hideValues;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: AppThemeColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppThemeColors.primaryGreen.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.alias,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Corte día ${card.cutOffDay} · Cuota \$${formatCurrencyDisplay(card.managementFee, hideValues)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
