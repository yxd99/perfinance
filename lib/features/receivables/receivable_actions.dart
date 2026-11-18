import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/receivables/receivable_notification_service.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Acciones sobre un cobro que comparten la lista de «Me deben» y su detalle.
// Toman el contenedor y el messenger antes de esperar: la fila deslizada o la
// pantalla pueden no existir cuando termina la escritura.

void _pushInBackground(ProviderContainer container) {
  container.read(syncServiceProvider).pushPendingIfOnline().catchError(
        (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'receivables.push'),
      );
}

/// Pide confirmar y elimina el deudor con todo su historial. Devuelve true
/// solo si quedó eliminado.
Future<bool> confirmAndDeleteReceivable(BuildContext context, Receivable receivable) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar deudor'),
      content: Text('¿Eliminás a "${receivable.debtorName}" y todo su historial de cobros? No se puede deshacer.'),
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
    await container.read(receivableRepositoryProvider).delete(receivable.id);
  } catch (e, st) {
    ErrorReporter.capture(e, st, operation: 'receivables.delete', details: {'receivable_id': receivable.id});
    messenger?.showSnackBar(const SnackBar(content: Text('No pudimos eliminar el deudor. Probá de nuevo.')));
    return false;
  }
  container.invalidate(receivablesListProvider);
  _pushInBackground(container);
  return true;
}

/// Pide confirmar y marca el cobro como cobrado por completo: registra un
/// cobro por lo que falta (y avisa por email si hay deudor con email) o, si
/// no falta nada, solo lo salda. Devuelve true si se guardó.
Future<bool> confirmAndSettleInFull(BuildContext context, Receivable receivable, {required double remaining}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Marcar como cobrada'),
      content: Text('¿Marcás a "${receivable.debtorName}" como cobrada por completo?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cobrar todo')),
      ],
    ),
  );
  if (ok != true) return false;

  try {
    if (remaining > 0) {
      await container.read(receivablePaymentRepositoryProvider).insert(
            ReceivablePayment(
              id: const Uuid().v4(),
              receivableId: receivable.id,
              amount: remaining,
              date: DateTime.now(),
            ),
          );
    } else {
      await container.read(receivableRepositoryProvider).settle(receivable.id);
    }
  } catch (e, st) {
    ErrorReporter.capture(e, st, operation: 'receivables.settle_all', details: {'receivable_id': receivable.id});
    messenger?.showSnackBar(const SnackBar(content: Text('No pudimos guardar el cobro. Probá de nuevo.')));
    return false;
  }

  final email = receivable.debtorEmail;
  if (remaining > 0 && email != null) {
    try {
      await container.read(receivableNotificationServiceProvider).notify(
            ReceivableNotificationPayload(
              event: ReceivableNotificationEvent.paymentRecorded,
              recipientEmail: email,
              debtorName: receivable.debtorName,
              description: receivable.description,
              totalAmount: receivable.totalAmount,
              remainingBalance: 0,
              paymentAmount: remaining,
              paymentDate: DateTime.now(),
              creditorEmail: Supabase.instance.client.auth.currentUser?.email,
            ),
          );
    } catch (e, st) {
      // El cobro ya quedó guardado; solo falló el aviso por email.
      ErrorReporter.capture(e, st, operation: 'receivables.notify_settle_all', details: {'receivable_id': receivable.id});
    }
  }
  container.invalidate(receivablesListProvider);
  container.invalidate(receivablePaymentsProvider(receivable.id));
  _pushInBackground(container);
  return true;
}
