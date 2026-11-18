import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/core/config/supabase_config.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/expenses/expense_date_filter.dart';
import 'package:perfinance/features/expenses/expense_export_service.dart';
import 'package:perfinance/features/expenses/expense_export_window.dart';
import 'package:perfinance/features/expenses/expense_form_screen.dart';
import 'package:perfinance/features/expenses/expense_list_formatting.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/quick_add_expense.dart';
import 'package:perfinance/features/expenses/widgets/account_note_chip.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/services/sync_service.dart';

/// Pestaña «Egresos»: lista agrupada por día con filtros de fecha y cuenta.
/// El registro nuevo entra por el «+» de la barra inferior.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  /// Filas ya deslizadas para borrar: se ocultan de inmediato, antes de que
  /// el provider recargue, para que el `Dismissible` no siga en el árbol.
  final Set<String> _removed = {};

  /// Rangos de uso diario en el control segmentado; «Ayer» y el rango
  /// personalizado viven en «Otra fecha».
  static const _segments = {
    ExpenseDateFilterType.today: 'Hoy',
    ExpenseDateFilterType.thisWeek: 'Semana',
    ExpenseDateFilterType.currentMonth: 'Mes',
    ExpenseDateFilterType.last30Days: '30 días',
  };

  static const _segmentFilters = {
    ExpenseDateFilterType.today: ExpenseDateFilter.today,
    ExpenseDateFilterType.thisWeek: ExpenseDateFilter.thisWeek,
    ExpenseDateFilterType.currentMonth: ExpenseDateFilter.currentMonth,
    ExpenseDateFilterType.last30Days: ExpenseDateFilter.last30Days,
  };

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(filteredExpensesListProvider);
    final display = ref.watch(expensePaymentDisplayProvider).valueOrNull ??
        const ExpensePaymentDisplay(cardAliases: {}, methodNames: {});
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    final visible = asyncList.valueOrNull?.where((e) => !_removed.contains(e.id)).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('Egresos'),
          toolbarHeight: 44,
          expandedHeight: 100,
          actions: [
            IconButton(
              icon: const Icon(CupertinoIcons.square_arrow_up),
              tooltip: 'Exportar egresos por correo',
              onPressed: () => _sendExpenseExportEmail(context),
            ),
          ],
        ),
        SliverToBoxAdapter(child: _TotalLine(expenses: visible, hideValues: hideValues)),
        SliverToBoxAdapter(child: _buildFilterBar(context)),
        ...asyncList.when(
          skipLoadingOnReload: true,
          data: (_) => _buildList(context, visible ?? const [], display, hideValues),
          loading: () => const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ],
          error: (e, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(
                message: UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.expensesLoadFailed),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildList(
    BuildContext context,
    List<Expense> list,
    ExpensePaymentDisplay display,
    bool hideValues,
  ) {
    if (list.isEmpty) {
      final copy = expenseEmptyCopy(
        hasAnyExpenses: ref.watch(expensesListProvider).valueOrNull?.isNotEmpty ?? true,
        filter: ref.watch(selectedExpenseDateFilterProvider).type,
        hasPaymentFilter: ref.watch(selectedExpensePaymentIdsFilterProvider).isNotEmpty,
      );
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyExpenses(copy: copy, onAction: () => _runEmptyAction(copy.action)),
        ),
      ];
    }

    final now = DateTime.now();
    // Encabezados de día y filas en una sola lista plana para un único builder.
    final items = <Object>[];
    for (final g in groupExpensesByDay(list)) {
      items.add(g);
      items.addAll(g.expenses);
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 24),
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            if (item is ExpenseDayGroup) {
              return _DayHeader(
                label: expenseDayLabel(item.day, now: now),
                total: formatCurrencyDisplay(item.total, hideValues),
              );
            }
            final e = item as Expense;
            return _ExpenseRow(
              key: ValueKey(e.id),
              expense: e,
              accountAlias: display.aliasFor(e),
              hideValues: hideValues,
              onTap: () => _openForm(context, edit: e),
              confirmDelete: () => _confirmDelete(context),
              onDeleted: () => _delete(e),
            );
          },
        ),
      ),
    ];
  }

  void _runEmptyAction(ExpenseEmptyAction action) {
    switch (action) {
      case ExpenseEmptyAction.logExpense:
        showQuickAddExpense(context, ref);
      case ExpenseEmptyAction.showCurrentMonth:
        ref.read(selectedExpenseDateFilterProvider.notifier).state = ExpenseDateFilter.currentMonth;
      case ExpenseEmptyAction.showLast30Days:
        ref.read(selectedExpenseDateFilterProvider.notifier).state = ExpenseDateFilter.last30Days;
      case ExpenseEmptyAction.clearPaymentFilter:
        ref.read(selectedExpensePaymentIdsFilterProvider.notifier).state = {};
    }
  }

  Widget _buildFilterBar(BuildContext context) {
    final c = context.colors;
    final selected = ref.watch(selectedExpenseDateFilterProvider);
    final paymentFilter = ref.watch(selectedExpensePaymentIdsFilterProvider);
    final cards = ref.watch(creditCardsListProvider).valueOrNull ?? const <CreditCard>[];
    final methods = ref.watch(paymentMethodsListProvider).valueOrNull ?? const <PaymentMethod>[];
    final isCustom = selected.type == ExpenseDateFilterType.custom;
    final now = DateTime.now();
    final customLabel = isCustom
        ? '${expenseShortDate(selected.range!.start, now: now)} – ${expenseShortDate(selected.range!.end, now: now)}'
        : 'Rango personalizado';
    final n = paymentFilter.length;

    final segment = _segments.containsKey(selected.type) ? selected.type : null;
    final otherLabel = isCustom
        ? customLabel
        : selected.type == ExpenseDateFilterType.yesterday
            ? 'Ayer'
            : 'Otra fecha';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoSlidingSegmentedControl<ExpenseDateFilterType>(
            groupValue: segment,
            backgroundColor: c.track,
            thumbColor: c.surface,
            children: {
              for (final e in _segments.entries)
                e.key: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: segment == e.key ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
            },
            onValueChanged: (type) {
              if (type == null) return;
              ref.read(selectedExpenseDateFilterProvider.notifier).state = _segmentFilters[type]!;
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SecondaryChip(
                icon: CupertinoIcons.calendar,
                label: otherLabel,
                active: segment == null,
                onPressed: () => _pickOtherDate(context),
              ),
              if (cards.isNotEmpty || methods.isNotEmpty)
                _SecondaryChip(
                  icon: CupertinoIcons.creditcard,
                  label: n == 0 ? 'Tarjetas y cuentas' : 'Cuentas ($n)',
                  active: n > 0,
                  onPressed: () => _openPaymentFilterSheet(context, cards, methods),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Hoja de acciones de iOS con los rangos que no están en el segmentado.
  Future<void> _pickOtherDate(BuildContext context) async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'yesterday'),
            child: const Text('Ayer'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'custom'),
            child: const Text('Elegir un rango…'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'yesterday') {
      ref.read(selectedExpenseDateFilterProvider.notifier).state = ExpenseDateFilter.yesterday;
    } else if (choice == 'custom') {
      await _pickCustomRange(context);
    }
  }

  void _openPaymentFilterSheet(
    BuildContext context,
    List<CreditCard> cards,
    List<PaymentMethod> methods,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.55;
        final c = ctx.colors;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filtrar por tarjeta o cuenta',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Sin selección ves todos los egresos del período. Si marcás opciones, solo vas a ver los cargados a esas tarjetas o cuentas.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, sheetRef, _) {
                  final selected = sheetRef.watch(selectedExpensePaymentIdsFilterProvider);
                  void toggle(String id, bool? v) {
                    final next = Set<String>.from(selected);
                    v == true ? next.add(id) : next.remove(id);
                    sheetRef.read(selectedExpensePaymentIdsFilterProvider.notifier).state = next;
                  }

                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxH),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (cards.isNotEmpty) ...[
                          _SheetSectionTitle('Tarjetas de crédito', top: 4),
                          for (final card in cards)
                            CheckboxListTile(
                              value: selected.contains(card.id),
                              onChanged: (v) => toggle(card.id, v),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(card.alias),
                              secondary: AccountNoteChip(color: ref.accountHue(context, card.id)),
                            ),
                        ],
                        if (methods.isNotEmpty) ...[
                          _SheetSectionTitle('Cuentas de ahorro', top: 12),
                          for (final m in methods)
                            CheckboxListTile(
                              value: selected.contains(m.id),
                              onChanged: (v) => toggle(m.id, v),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(m.name),
                              secondary: AccountNoteChip(color: ref.accountHue(context, m.id)),
                            ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      ref.read(selectedExpensePaymentIdsFilterProvider.notifier).state = {};
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Quitar filtro'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Listo'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendExpenseExportEmail(BuildContext context) async {
    if (!SupabaseConfig.isConfigured) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Supabase no está configurado en esta compilación.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final list = await ref.read(filteredExpensesListProvider.future);
    if (!context.mounted) return;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(UserFriendlyErrors.expenseExportNoRows)),
      );
      return;
    }

    final filter = ref.read(selectedExpenseDateFilterProvider);
    final window = ExpenseExportWindow.fromFilter(filter);

    BuildContext? loadingDialogContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        loadingDialogContext = dialogContext;
        return const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator.adaptive()),
        );
      },
    );

    try {
      await ref.read(expenseExportServiceProvider).sendExpenseExportEmail(window);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te enviamos el archivo por correo.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(UserFriendlyErrors.expenseExportEmailMessage(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      final dc = loadingDialogContext;
      if (dc != null && dc.mounted) {
        Navigator.of(dc).pop();
      }
    }
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final current = ref.read(selectedExpenseDateFilterProvider);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: current.type == ExpenseDateFilterType.custom
          ? current.range
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (range != null) {
      ref.read(selectedExpenseDateFilterProvider.notifier).state = ExpenseDateFilter.custom(range);
    }
  }

  void _openForm(BuildContext context, {Expense? edit}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExpenseFormScreen(edit: edit)),
    ).then((_) => ref.invalidate(expensesListProvider));
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar este egreso?'),
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
    return ok == true;
  }

  Future<void> _delete(Expense e) async {
    setState(() => _removed.add(e.id));
    try {
      await ref.read(expenseRepositoryProvider).delete(e.id);
    } catch (err, st) {
      ErrorReporter.capture(err, st, operation: 'expenses.delete', details: {'expense_id': e.id});
      if (!mounted) return;
      setState(() => _removed.remove(e.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No pudimos eliminar el egreso. Probá de nuevo.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    ref.invalidate(expensesListProvider);
    ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
  }
}

/// «Total: $1.284.300» del filtro activo, discreto bajo el título.
class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.expenses, required this.hideValues});

  final List<Expense>? expenses;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final list = expenses;
    if (list == null || list.isEmpty) return const SizedBox(height: 4);
    final c = context.colors;
    final total = list.fold<double>(0, (s, e) => s + e.amount);
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Total: ', style: style?.copyWith(color: c.textMuted)),
            TextSpan(
              text: '\$${formatCurrencyDisplay(total, hideValues)}',
              style: style?.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filtro secundario (rango, cuentas): sin relleno salvo que esté activo.
class _SecondaryChip extends StatelessWidget {
  const _SecondaryChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.accent : c.textMuted;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: fg),
        label: Text(label),
        labelStyle: TextStyle(color: fg, fontWeight: active ? FontWeight.w600 : FontWeight.w500),
        backgroundColor: active ? c.accentSoft : Colors.transparent,
        side: BorderSide(color: active ? c.accent : c.divider),
        onPressed: onPressed,
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.total});

  final String label;
  final String total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(child: Text(label, style: t.titleSmall?.copyWith(color: c.ink))),
            Text(
              '\$$total',
              style: t.bodySmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({
    super.key,
    required this.expense,
    required this.accountAlias,
    required this.hideValues,
    required this.onTap,
    required this.confirmDelete,
    required this.onDeleted,
  });

  final Expense expense;
  final String accountAlias;
  final bool hideValues;
  final VoidCallback onTap;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final text = expenseRowText(expense.description, accountAlias);
    final amount = '\$${formatCurrencyDisplay(expense.amount, hideValues)}';

    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Eliminar egreso'): () async {
          if (await confirmDelete()) onDeleted();
        },
      },
      child: Dismissible(
        key: ValueKey('dismiss-${expense.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => confirmDelete(),
        onDismissed: (_) => onDeleted(),
        background: Container(
          color: c.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Icon(CupertinoIcons.trash, color: c.onDanger, semanticLabel: 'Eliminar'),
        ),
        child: Material(
          color: c.canvas,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    AccountNoteChip(color: ref.accountHue(context, expense.paymentRef)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            text.title,
                            style: t.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (text.fromWallet) ...[
                                const _WalletMarker(),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  accountAlias,
                                  style: t.bodySmall?.copyWith(color: c.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      amount,
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontFeatures: kTabularFigures),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletMarker extends StatelessWidget {
  const _WalletMarker();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.divider),
      ),
      child: Text(
        'Wallet',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.textMuted),
      ),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle(this.text, {required this.top});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses({required this.copy, required this.onAction});

  final ExpenseEmptyCopy copy;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isLog = copy.action == ExpenseEmptyAction.logExpense;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.doc_text, size: 40, color: c.textMuted),
          const SizedBox(height: 12),
          Text(copy.message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (isLog)
            FilledButton.icon(onPressed: onAction, icon: const Icon(CupertinoIcons.add), label: Text(copy.actionLabel))
          else
            FilledButton.tonal(onPressed: onAction, child: Text(copy.actionLabel)),
        ],
      ),
    );
  }
}
