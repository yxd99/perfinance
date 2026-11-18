import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/core/widgets/app_empty_state.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/core/widgets/summary_total_bar.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/receivables/receivable_detail_screen.dart';
import 'package:perfinance/features/receivables/receivable_form_screen.dart';
import 'package:perfinance/features/receivables/receivable_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';
import 'package:uuid/uuid.dart';

final receivableListFilterProvider =
    StateProvider<ReceivableListFilter>((ref) => ReceivableListFilter.active);

class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(receivableListFilterProvider);
    final asyncList = ref.watch(filteredReceivablesProvider(filter));
    final asyncTotal = ref.watch(receivablesTotalOutstandingProvider);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'Activas',
                selected: filter == ReceivableListFilter.active,
                onTap: () => ref.read(receivableListFilterProvider.notifier).state =
                    ReceivableListFilter.active,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Cobradas',
                selected: filter == ReceivableListFilter.settled,
                onTap: () => ref.read(receivableListFilterProvider.notifier).state =
                    ReceivableListFilter.settled,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Todas',
                selected: filter == ReceivableListFilter.all,
                onTap: () => ref.read(receivableListFilterProvider.notifier).state =
                    ReceivableListFilter.all,
              ),
            ],
          ),
        ),
        Expanded(
          child: asyncList.when(
            data: (views) {
              if (views.isEmpty) {
                return AppEmptyState(
                  icon: Icons.handshake_outlined,
                  message: 'Nadie te debe plata por ahora.',
                  actionLabel: 'Agregar deudor',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReceivableFormScreen()),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: views.length,
                itemBuilder: (context, i) {
                  final view = views[i];
                  return _ReceivableCard(
                    view: view,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReceivableDetailScreen(receivable: view.receivable),
                      ),
                    ),
                    onSettleAll: view.receivable.status == ReceivableStatus.active
                        ? () => _settleAll(context, ref, view)
                        : null,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorState(message: e.toString()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReceivableFormScreen()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar deudor'),
                ),
              ),
              const SizedBox(height: 8),
              asyncTotal.when(
                data: (total) => SummaryTotalBar(
                  label: 'Total por cobrar',
                  amount: '\$${formatCurrency(total)}',
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _settleAll(BuildContext context, WidgetRef ref, ReceivableView view) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Marcar como cobrada'),
        content: Text('¿Marcar "${view.receivable.debtorName}" como cobrada por completo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cobrar todo'),
          ),
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
          await ref.read(receivableNotificationServiceProvider).notify(
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
        } catch (_) {}
      }
    } else {
      await ref.read(receivableRepositoryProvider).settle(view.receivable.id);
    }
    ref.invalidate(receivablesListProvider);
    ref.invalidate(receivablePaymentsProvider(view.receivable.id));
    ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
  }
}

class _ReceivableCard extends StatelessWidget {
  const _ReceivableCard({required this.view, required this.onTap, this.onSettleAll});

  final ReceivableView view;
  final VoidCallback onTap;
  final VoidCallback? onSettleAll;

  @override
  Widget build(BuildContext context) {
    final r = view.receivable;
    final remaining = view.remainingBalance;
    final isSettled = r.status == ReceivableStatus.settled;
    final progress = r.totalAmount > 0
        ? (view.totalPaid / r.totalAmount).clamp(0.0, 1.0)
        : 0.0;

    Widget card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: context.colors.accentSoft,
                    child: Icon(Icons.person_outline, color: context.colors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      r.debtorName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  if (isSettled) _Pill(label: 'Cobrada', color: context.colors.positive),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  r.debtorEmail ?? 'Sin email',
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: context.colors.track,
                valueColor: AlwaysStoppedAnimation(context.colors.accent),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${formatCurrency(view.totalPaid)} / \$${formatCurrency(r.totalAmount)}',
                    style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                  ),
                  Text(
                    remaining <= 0 ? 'Cobrado al 100%' : 'Falta: \$${formatCurrency(remaining)}',
                    style: TextStyle(
                      color: remaining <= 0 ? context.colors.positive : context.colors.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (onSettleAll != null) {
      return Dismissible(
        key: ValueKey('receivable-${r.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: context.colors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.check_circle_outline, color: context.colors.onAccent),
              const SizedBox(width: 8),
              Text('Cobrar todo', style: TextStyle(color: context.colors.onAccent, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        confirmDismiss: (_) async {
          onSettleAll?.call();
          return false;
        },
        child: card,
      );
    }
    return card;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
