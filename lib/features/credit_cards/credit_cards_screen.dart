import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No hay tarjetas. Añade una.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openForm(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir tarjeta'),
                ),
              ],
            ),
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
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(card.alias),
                subtitle: Text('Corte día ${card.cutOffDay} · Cuota \$${formatCurrencyDisplay(card.managementFee, hideValues)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreditCardDetailScreen(cardId: card.id),
                  ),
                ),
                onLongPress: () => _editCard(context, ref, card),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.credit_card_off, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.cardsLoadFailed),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
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
