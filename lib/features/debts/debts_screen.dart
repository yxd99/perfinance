import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/core/widgets/paid_stamp.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/data/repositories/mirrored_debt_repository.dart';
import 'package:perfinance/features/debts/debt_detail_screen.dart';
import 'package:perfinance/features/debts/debt_form_screen.dart';
import 'package:perfinance/features/debts/debt_list_copy.dart';
import 'package:perfinance/features/debts/debts_provider.dart';

const _filterLabels = {
  DebtListFilter.active: 'Activas',
  DebtListFilter.paid: 'Pagadas',
  DebtListFilter.all: 'Todas',
  DebtListFilter.hidden: 'Ocultas',
};

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(debtsListProvider);
    ref.invalidate(filteredDebtsWithPaidProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final asyncList = ref.watch(filteredDebtsWithPaidProvider);
    final filter = ref.watch(debtListFilterProvider);
    final query = ref.watch(debtSearchQueryProvider);
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    final asyncTotal = ref.watch(outstandingDebtsTotalProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título grande igual al de las otras pestañas del shell, con la
        // acción de agregar como en una barra de navegación de iOS.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 52, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Deudas',
                    style: t.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(CupertinoIcons.add, color: c.accent),
                tooltip: 'Agregar deuda',
                onPressed: () => _openForm(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: CupertinoSearchTextField(
            controller: _searchController,
            placeholder: 'Buscar deuda',
            padding: const EdgeInsetsDirectional.fromSTEB(6, 12, 6, 12),
            backgroundColor: c.track,
            itemColor: c.textMuted,
            style: t.bodyLarge?.copyWith(color: c.ink),
            placeholderStyle: t.bodyLarge?.copyWith(color: c.textMuted),
            onChanged: (v) => ref.read(debtSearchQueryProvider.notifier).state = v,
            onSuffixTap: () {
              _searchController.clear();
              ref.read(debtSearchQueryProvider.notifier).state = '';
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: CupertinoSlidingSegmentedControl<DebtListFilter>(
            groupValue: filter,
            backgroundColor: c.track,
            thumbColor: c.surface,
            children: {
              for (final e in _filterLabels.entries)
                e.key: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    e.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.ink, fontWeight: filter == e.key ? FontWeight.w600 : FontWeight.w500),
                  ),
                ),
            },
            onValueChanged: (v) {
              if (v != null) ref.read(debtListFilterProvider.notifier).state = v;
            },
          ),
        ),
        Expanded(
          child: asyncList.when(
            data: (list) {
              if (list.isEmpty) {
                final showAll = filter == DebtListFilter.active && query.trim().isEmpty;
                return _EmptyList(
                  message: debtsEmptyMessage(filter, query),
                  actionLabel: showAll ? 'Ver todas' : 'Agregar deuda',
                  onAction: showAll
                      ? () => ref.read(debtListFilterProvider.notifier).state = DebtListFilter.all
                      : () => _openForm(context),
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _TotalLine(total: asyncTotal.valueOrNull, hideValues: hideValues),
                  _DebtGroup(children: [for (final item in list) _buildRow(context, item, hideValues)]),
                ],
              );
            },
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) =>
                AppErrorState(message: UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.debtsLoadFailed)),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, DebtWithPaid item, bool hideValues) {
    final c = context.colors;
    void openDetail() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DebtDetailScreen(debt: item.debt)),
    ).then((_) => _refresh());

    // Deudas recibidas: solo lectura, sin deslizar para pagar.
    if (item.debt.isMirrored) {
      return MirroredDebtCard(
        item: item,
        hideValues: hideValues,
        onTap: openDetail,
        onDelete: item.debt.isRevoked
            ? () async {
                await ref.read(mirroredDebtRepositoryProvider).deleteByMirroredId(item.debt.mirroredDebtId!);
                _refresh();
              }
            : null,
      );
    }

    final canPay = item.debt.status == DebtStatus.active;
    Future<bool> pay() async {
      final ok = await _confirmPayDialog(context, item.debt.name);
      if (ok != true) return false;
      await ref.read(debtRepositoryProvider).payDebt(item.debt.id);
      _refresh();
      return true;
    }

    return Semantics(
      customSemanticsActions: {
        if (canPay) const CustomSemanticsAction(label: 'Marcar como pagada'): () => pay(),
        const CustomSemanticsAction(label: 'Editar deuda'): () => _editDebt(context, item.debt),
      },
      child: Dismissible(
        key: ValueKey('debt-${item.debt.id}'),
        direction: canPay ? DismissDirection.endToStart : DismissDirection.none,
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
                'Pagar',
                style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        // Se paga en el repositorio; la fila no se descarta, cambia de estado.
        confirmDismiss: (_) async {
          await pay();
          return false;
        },
        child: _DebtRow(
          item: item,
          hideValues: hideValues,
          onTap: openDetail,
          onLongPress: () => _editDebt(context, item.debt),
        ),
      ),
    );
  }

  Future<bool?> _confirmPayDialog(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como pagada'),
        content: Text('¿Marcar «$name» como pagada?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pagar')),
        ],
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtFormScreen())).then((_) => _refresh());
  }

  void _editDebt(BuildContext context, Debt debt) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DebtFormScreen(editDebt: debt))).then((_) => _refresh());
  }
}

/// «Total por pagar: $X» de las deudas activas, discreto sobre la lista.
class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.total, required this.hideValues});

  final double? total;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final value = total;
    if (value == null) return const SizedBox(height: 8);
    final c = context.colors;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Total por pagar: ',
              style: style?.copyWith(color: c.textMuted),
            ),
            TextSpan(
              text: '\$${formatCurrencyDisplay(value, hideValues)}',
              style: style?.copyWith(color: c.ink, fontWeight: FontWeight.w600, fontFeatures: kTabularFigures),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista agrupada inset sobre papel claro, con líneas finas entre filas.
class _DebtGroup extends StatelessWidget {
  const _DebtGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: c.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 16, color: c.divider),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.message, required this.actionLabel, required this.onAction});

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: c.accent,
                minimumSize: const Size(44, 44),
                textStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila base: nombre, línea de estado y a la derecha el monto o el sello.
class _RowShell extends StatelessWidget {
  const _RowShell({required this.title, required this.status, required this.trailing, this.onTap, this.onLongPress});

  final String title;
  final String status;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: t.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: t.bodySmall?.copyWith(color: c.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.chevron_forward, size: 16, color: c.textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.value, required this.owed, required this.hideValues});

  final double value;
  final bool owed;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      '\$${formatCurrencyDisplay(value, hideValues)}',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: kTabularFigures,
        color: owed ? c.danger : c.textMuted,
      ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.item, required this.hideValues, required this.onTap, required this.onLongPress});

  final DebtWithPaid item;
  final bool hideValues;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final remaining = debtRemaining(item);
    final Widget trailing = switch (item.debt.status) {
      DebtStatus.paid => const PaidStamp(label: 'Pagada'),
      DebtStatus.active => _Amount(value: remaining, owed: remaining > 0, hideValues: hideValues),
      DebtStatus.hidden => _Amount(value: remaining, owed: false, hideValues: hideValues),
    };
    return _RowShell(
      title: item.debt.name,
      status: debtStatusLine(item, hideValues: hideValues),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// Fila de una deuda recibida (espejo): solo lectura, sin deslizar para pagar.
/// Pública para poder probarla directo.
class MirroredDebtCard extends StatelessWidget {
  const MirroredDebtCard({super.key, required this.item, this.hideValues = false, this.onTap, this.onDelete});

  final DebtWithPaid item;
  final bool hideValues;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final debt = item.debt;
    final remaining = debtRemaining(item);
    return Material(
      color: c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RowShell(
            title: debt.name,
            status: debtStatusLine(item, hideValues: hideValues),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!debt.isRevoked) _Amount(value: remaining, owed: remaining > 0, hideValues: hideValues),
                const SizedBox(height: 2),
                const _ReceivedMarker(),
              ],
            ),
            onTap: onTap,
          ),
          if (debt.isRevoked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Esta deuda fue cancelada por ${debt.creditorEmail}',
                      style: t.bodySmall?.copyWith(color: c.textMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(foregroundColor: c.danger, minimumSize: const Size(44, 44)),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Marca «Recibida», como la de Wallet en Egresos: contorno fino, sin relleno.
class _ReceivedMarker extends StatelessWidget {
  const _ReceivedMarker();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.info),
      ),
      child: Text('Recibida', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.info)),
    );
  }
}
