import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/widgets/inset_add_row.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/app_empty_state.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/core/widgets/paid_stamp.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/receivables/receivable_detail_screen.dart';
import 'package:perfinance/features/receivables/receivable_form_screen.dart';
import 'package:perfinance/features/receivables/receivable_notification_service.dart';
import 'package:perfinance/features/receivables/receivable_row_status.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';
import 'package:perfinance/features/receivables/widgets/inset_list_group.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final receivableListFilterProvider = StateProvider<ReceivableListFilter>((ref) => ReceivableListFilter.active);

const _filterLabels = <ReceivableListFilter, String>{
  ReceivableListFilter.active: 'Activas',
  ReceivableListFilter.settled: 'Cobradas',
  ReceivableListFilter.all: 'Todas',
};

/// Cuerpo de «Me deben». El Scaffold y la barra los pone el hub «Más».
class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final filter = ref.watch(receivableListFilterProvider);
    final asyncList = ref.watch(filteredReceivablesProvider(filter));
    final asyncTotal = ref.watch(receivablesTotalOutstandingProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<ReceivableListFilter>(
              groupValue: filter,
              backgroundColor: c.track,
              thumbColor: c.surface,
              children: {
                for (final e in _filterLabels.entries)
                  e.key: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      e.value,
                      style: TextStyle(color: c.ink, fontWeight: filter == e.key ? FontWeight.w600 : FontWeight.w500),
                    ),
                  ),
              },
              onValueChanged: (value) {
                if (value == null) return;
                ref.read(receivableListFilterProvider.notifier).state = value;
              },
            ),
          ),
        ),
        Expanded(
          child: asyncList.when(
            skipLoadingOnReload: true,
            data: (views) {
              if (views.isEmpty) {
                final settledTab = filter == ReceivableListFilter.settled;
                return AppEmptyState(
                  icon: CupertinoIcons.person_2,
                  message: settledTab
                      ? 'Todavía no saldaste ningún cobro. Cuando alguien te pague todo, queda acá.'
                      : 'Nadie te debe plata por ahora.',
                  actionLabel: settledTab ? null : 'Agregar deudor',
                  onAction: settledTab ? null : () => _openForm(context),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // Total tranquilo arriba de la lista, como en Deudas y Egresos.
                  asyncTotal.when(
                    data: (total) => Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                      child: Text.rich(
                        TextSpan(
                          text: 'Total por cobrar: ',
                          style: TextStyle(color: c.textMuted),
                          children: [
                            TextSpan(
                              text: '\$${formatCurrency(total)}',
                              style: TextStyle(color: c.ink, fontWeight: FontWeight.w700, fontFeatures: kTabularFigures),
                            ),
                          ],
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  InsetListGroup(
                    children: [
                      for (final view in views)
                        _ReceivableRow(
                          view: view,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ReceivableDetailScreen(receivable: view.receivable)),
                          ),
                          onSettleAll: view.receivable.status == ReceivableStatus.active
                              ? () => _settleAll(context, ref, view)
                              : null,
                        ),
                      InsetAddRow(label: 'Agregar deudor', onTap: () => _openForm(context)),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => AppErrorState(
              message: UserFriendlyErrors.fromAsyncError(e, 'No se pudo cargar lo que te deben. Probá de nuevo.'),
              onRetry: () => ref.invalidate(receivablesListProvider),
            ),
          ),
        ),
      ],
    );
  }

  void _openForm(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivableFormScreen()));
  }

  Future<void> _settleAll(BuildContext context, WidgetRef ref, ReceivableView view) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como cobrada'),
        content: Text('¿Marcás a "${view.receivable.debtorName}" como cobrada por completo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cobrar todo')),
        ],
      ),
    );
    if (ok != true) return;

    final remaining = view.remainingBalance;
    if (remaining > 0) {
      final payRepo = ref.read(receivablePaymentRepositoryProvider);
      await payRepo.insert(
        ReceivablePayment(
          id: const Uuid().v4(),
          receivableId: view.receivable.id,
          amount: remaining,
          date: DateTime.now(),
        ),
      );
      if (view.receivable.debtorEmail != null) {
        try {
          await ref
              .read(receivableNotificationServiceProvider)
              .notify(
                ReceivableNotificationPayload(
                  event: ReceivableNotificationEvent.paymentRecorded,
                  recipientEmail: view.receivable.debtorEmail!,
                  debtorName: view.receivable.debtorName,
                  totalAmount: view.receivable.totalAmount,
                  remainingBalance: 0,
                  paymentAmount: remaining,
                  paymentDate: DateTime.now(),
                  creditorEmail: Supabase.instance.client.auth.currentUser?.email,
                ),
              );
        } catch (e, st) {
          // El cobro ya quedó guardado; solo falló el aviso por email.
          ErrorReporter.capture(
            e,
            st,
            operation: 'receivables.notify_settle_all',
            details: {'receivable_id': view.receivable.id},
          );
        }
      }
    } else {
      await ref.read(receivableRepositoryProvider).settle(view.receivable.id);
    }
    ref.invalidate(receivablesListProvider);
    ref.invalidate(receivablePaymentsProvider(view.receivable.id));
    ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
  }
}

class _ReceivableRow extends StatelessWidget {
  const _ReceivableRow({required this.view, required this.onTap, this.onSettleAll});

  final ReceivableView view;
  final VoidCallback onTap;
  final VoidCallback? onSettleAll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final r = view.receivable;
    final status = receivableRowStatus(view);
    final isActive = r.status == ReceivableStatus.active;
    final toneColor = switch (status.tone) {
      ReceivableRowTone.warning => c.warning,
      ReceivableRowTone.positive => c.positive,
      ReceivableRowTone.muted => c.textMuted,
    };
    final progress = r.totalAmount > 0 ? (view.totalPaid / r.totalAmount).clamp(0.0, 1.0).toDouble() : 0.0;

    final row = InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.debtorName,
                      style: t.bodyLarge?.copyWith(color: isActive ? c.ink : c.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.detail,
                      style: t.bodySmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures),
                      maxLines: 2,
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 6),
                      ExcludeSemantics(
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: c.track,
                          valueColor: AlwaysStoppedAnimation(c.accent),
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (status.stamp != null)
                PaidStamp(label: status.stamp!)
              else if (status.trailing != null)
                Flexible(
                  child: Text(
                    status.trailing!,
                    textAlign: TextAlign.right,
                    style: t.titleSmall?.copyWith(
                      color: toneColor,
                      fontWeight: FontWeight.w700,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right, size: 16, color: c.textMuted),
            ],
          ),
        ),
      ),
    );

    if (onSettleAll == null) return row;
    return Dismissible(
      key: ValueKey('receivable-${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: c.accent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(CupertinoIcons.checkmark_circle, color: c.onAccent),
            const SizedBox(width: 8),
            Text(
              'Cobrar todo',
              style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onSettleAll?.call();
        return false;
      },
      child: row,
    );
  }
}
