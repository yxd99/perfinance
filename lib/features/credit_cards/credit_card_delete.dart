import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/services/sync_service.dart';

/// Pide confirmar y borra la tarjeta. Devuelve true solo si quedó borrada.
///
/// Lo usan el deslizamiento de la lista, la acción de VoiceOver y el
/// formulario de edición. Toma el contenedor y el messenger antes de esperar:
/// la fila deslizada puede no existir cuando termina el borrado.
Future<bool> confirmAndDeleteCard(BuildContext context, CreditCard card) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar tarjeta'),
      content: Text('¿Eliminar "${card.alias}"? Los pagos de esta tarjeta se quitarán al sincronizar.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger, foregroundColor: ctx.colors.onDanger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await container.read(creditCardRepositoryProvider).delete(card.id);
  } catch (e, st) {
    ErrorReporter.capture(e, st, operation: 'credit_cards.delete', details: {'card_id': card.id});
    messenger?.showSnackBar(const SnackBar(content: Text('No pudimos eliminar la tarjeta. Probá de nuevo.')));
    return false;
  }
  container.invalidate(creditCardsListProvider);
  container.invalidate(dashboardDebtProvider);
  container.invalidate(expensesListProvider);
  container.invalidate(automaticPaymentsListProvider);
  container.read(syncServiceProvider).pushPendingIfOnline().catchError(
        (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'credit_cards.push'),
      );
  return true;
}
