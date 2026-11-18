import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/widgets/row_actions_button.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/inset_add_row.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/features/credit_cards/credit_card_delete.dart';
import 'package:perfinance/features/credit_cards/credit_card_list_view.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/credit_cards/credit_card_detail_screen.dart';
import 'package:perfinance/features/credit_cards/credit_card_form_screen.dart';
import 'package:perfinance/features/credit_cards/widgets/card_inset_group.dart';

/// Lista de tarjetas. Se abre desde «Más», que le pone el Scaffold y el título:
/// aquí solo va el cuerpo.
class CreditCardsScreen extends ConsumerWidget {
  const CreditCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCards = ref.watch(creditCardsListProvider);
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    return asyncCards.when(
      data: (cards) {
        if (cards.isEmpty) return _EmptyCards(onAdd: () => _openForm(context));
        final sortedCards = sortCardsActiveFirst(cards);
        return ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          children: [
            CardInsetGroup(
              dividerIndent: 62,
              children: [
                for (final card in sortedCards)
                  _CreditCardRow(
                    card: card,
                    hideValues: hideValues,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreditCardDetailScreen(cardId: card.id),
                      ),
                    ),
                  ),
                InsetAddRow(label: 'Agregar tarjeta', onTap: () => _openForm(context)),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => AppErrorState(
        message: UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.cardsLoadFailed),
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreditCardFormScreen()),
    );
  }
}

/// Fila de tarjeta: billete con el tono de la cuenta, alias, una línea de
/// estado y chevron. Las desactivadas quedan visibles pero apagadas.
///
/// Tocar abre el detalle (y desde ahí se edita); deslizar a la izquierda
/// elimina, con confirmación. VoiceOver tiene la misma acción de eliminar.
class _CreditCardRow extends ConsumerWidget {
  const _CreditCardRow({
    required this.card,
    required this.hideValues,
    required this.onTap,
  });

  final CreditCard card;
  final bool hideValues;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final hue = ref.accountHue(context, card.id);
    return Semantics(
      container: true,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Eliminar tarjeta'): () => confirmAndDeleteCard(context, card),
      },
      child: Dismissible(
        key: ValueKey('dismiss-card-${card.id}'),
        direction: DismissDirection.endToStart,
        // Se borra dentro de la confirmación: si falla, la fila vuelve a su lugar.
        confirmDismiss: (_) => confirmAndDeleteCard(context, card),
        background: Container(
          color: c.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Icon(CupertinoIcons.trash, color: c.onDanger, semanticLabel: 'Eliminar'),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      key: ValueKey('card-hue-${card.id}'),
                      width: 34,
                      height: 22,
                      decoration: BoxDecoration(
                        // Desactivada: el billete se ve desteñido, sin cambiar de tono.
                        color: card.isActive ? hue : hue.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          card.alias,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyLarge?.copyWith(color: card.isActive ? c.ink : c.textMuted),
                        ),
                        Text(
                          cardStatusLine(card, hideValues: hideValues),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures),
                        ),
                      ],
                    ),
                  ),
                  RowActionsButton(
                    title: card.alias,
                    actions: [
                      RowAction(label: 'Ver detalle', icon: CupertinoIcons.info_circle, onSelected: onTap),
                      RowAction(
                        label: 'Eliminar tarjeta',
                        icon: CupertinoIcons.trash,
                        destructive: true,
                        onSelected: () => confirmAndDeleteCard(context, card),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.creditcard, size: 44, color: c.textMuted),
            const SizedBox(height: 12),
            Text(
              'Todavía no tienes tarjetas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: c.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Agrega una para registrar sus egresos y llevar la deuda.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAdd, child: const Text('Agregar tarjeta')),
          ],
        ),
      ),
    );
  }
}
