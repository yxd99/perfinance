import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/widgets/inset_add_row.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/app_empty_state.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payment_copy.dart';
import 'package:perfinance/features/automatic_payments/automatic_payment_form_screen.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/widgets/account_note_chip.dart';
import 'package:perfinance/services/sync_service.dart';

/// Cuerpo de «Auto-pagos». El Scaffold y la barra los pone el hub «Más».
class AutomaticPaymentsScreen extends ConsumerWidget {
  const AutomaticPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(automaticPaymentsListProvider);
    // Mientras cargan los nombres de las cuentas, la fila dice «Tarjeta» o «Medio».
    final display = ref.watch(expensePaymentDisplayProvider).valueOrNull;
    final hideValues = ref.watch(hideValuesProvider).value ?? false;

    return asyncList.when(
      skipLoadingOnReload: true,
      data: (list) {
        if (list.isEmpty) {
          return AppEmptyState(
            icon: CupertinoIcons.arrow_2_circlepath,
            message:
                'Todavía no tenés pagos automáticos. Agregá Netflix, el gimnasio o el arriendo '
                'y se registran solos como egreso cada período.',
            actionLabel: 'Agregar pago automático',
            onAction: () => _openForm(context, ref),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _InsetGroup(
              children: [
                for (final p in list)
                  _AutomaticPaymentRow(
                    payment: p,
                    accountName: p.paymentType == 'credit_card'
                        ? (display?.cardAliases[p.paymentRef] ?? 'Tarjeta')
                        : (display?.methodNames[p.paymentRef] ?? 'Medio'),
                    amount: '\$${formatCurrencyDisplay(p.amount, hideValues)}',
                    onTap: () => _openForm(context, ref, edit: p),
                    onDelete: () => _confirmAndDelete(context, p),
                  ),
                InsetAddRow(label: 'Agregar pago automático', onTap: () => _openForm(context, ref)),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => AppErrorState(
        message: UserFriendlyErrors.fromAsyncError(e, 'No se pudieron cargar los pagos automáticos. Probá de nuevo.'),
        onRetry: () => ref.invalidate(automaticPaymentsListProvider),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {AutomaticPayment? edit}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AutomaticPaymentFormScreen(edit: edit))).then((_) {
      ref.invalidate(automaticPaymentsListProvider);
      ref.invalidate(expensesListProvider);
    });
  }

  /// Pide confirmar y borra. Devuelve true solo si quedó borrado, así el
  /// deslizamiento vuelve la fila a su lugar si se cancela o falla. Toma el
  /// contenedor y el messenger antes de esperar: la fila puede desaparecer.
  Future<bool> _confirmAndDelete(BuildContext context, AutomaticPayment p) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pago automático'),
        content: Text('¿Eliminás "${p.description}"? Los egresos que ya generó se quedan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: c.onDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await container.read(automaticPaymentRepositoryProvider).delete(p.id);
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'automatic_payments.delete', details: {'id': p.id});
      messenger?.showSnackBar(const SnackBar(content: Text('No pudimos eliminar el pago automático. Probá de nuevo.')));
      return false;
    }
    container.invalidate(automaticPaymentsListProvider);
    container.read(syncServiceProvider).pushPendingIfOnline().catchError(
          (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'automatic_payments.push'),
        );
    return true;
  }
}

/// Fila de pago automático. Tocar abre la edición; deslizar a la izquierda
/// elimina, con confirmación. VoiceOver tiene la misma acción de eliminar.
class _AutomaticPaymentRow extends ConsumerWidget {
  const _AutomaticPaymentRow({
    required this.payment,
    required this.accountName,
    required this.amount,
    required this.onTap,
    required this.onDelete,
  });

  final AutomaticPayment payment;
  final String accountName;
  final String amount;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final paused = isAutomaticPaymentPaused(payment);
    final ink = paused ? c.textMuted : c.ink;
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Eliminar pago automático'): onDelete,
      },
      child: Dismissible(
        key: ValueKey('dismiss-auto-${payment.id}'),
        direction: DismissDirection.endToStart,
        // Se borra dentro de la confirmación: si falla, la fila vuelve a su lugar.
        confirmDismiss: (_) => onDelete(),
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
                  AccountNoteChip(color: ref.accountHue(context, payment.paymentRef)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.description,
                          style: t.bodyLarge?.copyWith(color: ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          automaticPaymentStatusLine(payment, accountName: accountName),
                          style: t.bodySmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    amount,
                    textAlign: TextAlign.right,
                    style: t.titleSmall?.copyWith(color: ink, fontWeight: FontWeight.w700, fontFeatures: kTabularFigures),
                  ),
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.chevron_right, size: 16, color: c.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InsetGroup extends StatelessWidget {
  const _InsetGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: c.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              // Filete alineado con el texto, después del billete de la cuenta.
              if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 50, color: c.divider),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
