import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/app_empty_state.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/core/widgets/summary_total_bar.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/data/repositories/mirrored_debt_repository.dart';
import 'package:perfinance/features/debts/debts_provider.dart';
import 'package:perfinance/features/debts/debt_detail_screen.dart';
import 'package:perfinance/features/debts/debt_form_screen.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(filteredDebtsWithPaidProvider);
    final filter = ref.watch(debtListFilterProvider);
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    final asyncTotal = ref.watch(outstandingDebtsTotalProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              return TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Buscar por descripción',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(debtSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
                onChanged: (v) => ref.read(debtSearchQueryProvider.notifier).state = v,
              );
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'Activas',
                selected: filter == DebtListFilter.active,
                onTap: () => ref.read(debtListFilterProvider.notifier).state = DebtListFilter.active,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Pagadas',
                selected: filter == DebtListFilter.paid,
                onTap: () => ref.read(debtListFilterProvider.notifier).state = DebtListFilter.paid,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Todas',
                selected: filter == DebtListFilter.all,
                onTap: () => ref.read(debtListFilterProvider.notifier).state = DebtListFilter.all,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Ocultas',
                selected: filter == DebtListFilter.hidden,
                onTap: () => ref.read(debtListFilterProvider.notifier).state = DebtListFilter.hidden,
              ),
            ],
          ),
        ),
        Expanded(
          child: asyncList.when(
            data: (list) {
              if (list.isEmpty) {
                return AppEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  message: 'No hay deudas que coincidan.',
                  actionLabel: filter == DebtListFilter.active ? 'Ver todas' : 'Agregar deuda',
                  onAction: filter == DebtListFilter.active
                      ? () => ref.read(debtListFilterProvider.notifier).state = DebtListFilter.all
                      : () => _openForm(context, ref),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: asyncTotal.when(
                      data: (total) => SummaryTotalBar(
                        label: 'Total deudas activas',
                        amount: '\$${formatCurrencyDisplay(total, hideValues)}',
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: list.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: FilledButton.icon(
                              onPressed: () => _openForm(context, ref),
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar deuda'),
                            ),
                          );
                        }
                        final item = list[i - 1];

                        // Mirrored debts: read-only branch, no Dismissible
                        if (item.debt.isMirrored) {
                          return MirroredDebtCard(
                            item: item,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DebtDetailScreen(debt: item.debt),
                              ),
                            ).then((_) {
                              ref.invalidate(debtsListProvider);
                              ref.invalidate(filteredDebtsWithPaidProvider);
                            }),
                            onDelete: item.debt.isRevoked
                                ? () async {
                                    await ref
                                        .read(mirroredDebtRepositoryProvider)
                                        .deleteByMirroredId(item.debt.mirroredDebtId!);
                                    ref.invalidate(debtsListProvider);
                                    ref.invalidate(filteredDebtsWithPaidProvider);
                                  }
                                : null,
                          );
                        }

                        // Normal debts: existing Dismissible swipe-to-pay path
                        return Dismissible(
                          key: ValueKey('debt-${item.debt.id}'),
                          direction: item.debt.status == DebtStatus.active
                              ? DismissDirection.endToStart
                              : DismissDirection.none,
                          background: Container(
                            color: AppThemeColors.primaryGreen,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Pagar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final ok = await _confirmPayDialog(context, item.debt.name);
                            if (ok != true) return false;
                            await ref.read(debtRepositoryProvider).payDebt(item.debt.id);
                            ref.invalidate(debtsListProvider);
                            ref.invalidate(filteredDebtsWithPaidProvider);
                            return false;
                          },
                          child: _DebtCard(
                            item: item,
                            hideValues: hideValues,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DebtDetailScreen(debt: item.debt),
                              ),
                            ).then((_) {
                              ref.invalidate(debtsListProvider);
                              ref.invalidate(filteredDebtsWithPaidProvider);
                            }),
                            onLongPress: () => _editDebt(context, ref, item.debt),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorState(
              message: UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.debtsLoadFailed),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _confirmPayDialog(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como pagada'),
        content: Text('¿Marcar "$name" como pagada?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pagar')),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DebtFormScreen()),
    ).then((_) {
      ref.invalidate(debtsListProvider);
      ref.invalidate(filteredDebtsWithPaidProvider);
    });
  }

  void _editDebt(BuildContext context, WidgetRef ref, Debt debt) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DebtFormScreen(editDebt: debt)),
    ).then((_) {
      ref.invalidate(debtsListProvider);
      ref.invalidate(filteredDebtsWithPaidProvider);
    });
  }
}

/// Public card widget for mirrored debts — read-only, no swipe-to-pay.
/// Exported so tests can render it directly.
class MirroredDebtCard extends StatelessWidget {
  const MirroredDebtCard({
    super.key,
    required this.item,
    this.onTap,
    this.onDelete,
  });

  final DebtWithPaid item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final debt = item.debt;
    return Opacity(
      opacity: debt.isRevoked ? 0.75 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                // "Recibida" badge — always shown for mirrored
                Positioned(
                  top: 0,
                  right: 0,
                  child: _Pill(label: 'Recibida', color: Colors.blueGrey),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(20, 12, 72, 12),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.blueGrey),
                  ),
                  title: Text(debt.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Registrada por ${debt.creditorEmail}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onTap,
                  // NO onLongPress — edit not allowed for mirrored
                ),
              ],
            ),
            if (debt.isRevoked) ...[
              _RevokedBanner(creditorEmail: debt.creditorEmail!),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                  ),
                  child: const Text('Eliminar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RevokedBanner extends StatelessWidget {
  const _RevokedBanner({required this.creditorEmail});
  final String creditorEmail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Esta deuda fue cancelada por $creditorEmail',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
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
      selectedColor: AppThemeColors.primaryGreen.withValues(alpha: 0.3),
      checkmarkColor: AppThemeColors.primaryGreen,
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.item,
    required this.hideValues,
    required this.onTap,
    required this.onLongPress,
  });

  final DebtWithPaid item;
  final bool hideValues;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final debt = item.debt;
    final paid = item.paid;
    final remaining = debt.totalAmount - paid;
    final installmentsPaid = debt.amountPerInstallment > 0
        ? (paid / debt.amountPerInstallment).floor()
        : 0;
    final badge = item.badgeKind;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (badge != DebtBadgeKind.none && badge != DebtBadgeKind.mirrored && badge != DebtBadgeKind.revokedMirrored)
            Positioned(
              top: 0,
              right: 0,
              child: _DebtStatusBadge(kind: badge),
            ),
          ListTile(
            contentPadding: EdgeInsets.fromLTRB(20, 12, badge != DebtBadgeKind.none ? 72 : 20, 12),
            leading: CircleAvatar(
              backgroundColor: AppThemeColors.primaryGreen.withValues(alpha: 0.2),
              child: Icon(Icons.account_balance_wallet_outlined, color: AppThemeColors.primaryGreen),
            ),
            title: Text(debt.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hideValues) ...[
                  Text('Total: \$${formatCurrencyDisplay(debt.totalAmount, hideValues)} · ${debt.numberOfInstallments} cuotas'),
                  Text('Pagado: $installmentsPaid/${debt.numberOfInstallments} cuotas · Falta: \$${formatCurrencyDisplay(remaining, hideValues)}'),
                ],
                Text(
                  'Vence: ${formatDisplayDate(debt.dueDate)}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ],
      ),
    );
  }
}

class _DebtStatusBadge extends StatelessWidget {
  const _DebtStatusBadge({required this.kind});
  final DebtBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case DebtBadgeKind.none:
      case DebtBadgeKind.mirrored:
      case DebtBadgeKind.revokedMirrored:
        return const SizedBox.shrink();
      case DebtBadgeKind.paid:
        return _Pill(label: 'Pagada', color: AppThemeColors.primaryGreen);
      case DebtBadgeKind.hidden:
        return _Pill(label: 'Oculta', color: AppThemeColors.neutralGrey);
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
