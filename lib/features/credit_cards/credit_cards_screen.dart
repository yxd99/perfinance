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
        final sortedCards = [...cards]
          ..sort((a, b) => (a.isActive == b.isActive) ? 0 : (a.isActive ? -1 : 1));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedCards.length + 1,
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
            final card = sortedCards[i - 1];
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
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(
        opacity: card.isActive ? 1.0 : 0.6,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: c.heroGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
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
                    Row(
                      children: [
                        Text(
                          card.alias,
                          style: TextStyle(
                            color: c.onHero,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (!card.isActive) ...[
                          const SizedBox(width: 8),
                          const _InactiveBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Corte día ${card.cutOffDay} · Cuota \$${formatCurrencyDisplay(card.managementFee, hideValues)}',
                      style: TextStyle(
                        color: c.onHeroMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.onHero),
            ],
          ),
        ),
      ),
    );
  }
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.onHeroSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Inactiva',
        style: TextStyle(color: c.onHero, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
