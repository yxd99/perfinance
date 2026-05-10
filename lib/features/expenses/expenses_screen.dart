import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/config/supabase_config.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/app_empty_state.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/core/widgets/summary_total_bar.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/expense_date_filter.dart';
import 'package:perfinance/features/expenses/expense_export_service.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/expenses/expense_export_window.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/features/expenses/expense_form_screen.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(filteredExpensesListProvider);
    final asyncDisplay = ref.watch(expensePaymentDisplayProvider);
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterBar(context, ref),
        Expanded(
          child: asyncList.when(
            data: (list) {
              final total = list.fold<double>(0, (s, e) => s + e.amount);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SummaryTotalBar(
                      label: 'Total egresos',
                      amount: '\$${formatCurrencyDisplay(total, hideValues)}',
                    ),
                  ),
                  Expanded(
                    child: _buildList(context, ref, list, asyncDisplay, hideValues),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorState(
              message: UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.expensesLoadFailed),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<Expense> list,
    AsyncValue<ExpensePaymentDisplay> asyncDisplay,
    bool hideValues,
  ) {
    if (list.isEmpty) {
      return AppEmptyState(
        icon: Icons.payments_outlined,
        message: 'No hay egresos registrados',
        actionLabel: 'Registrar egreso',
        onAction: () => _openForm(context, ref),
      );
    }
    return asyncDisplay.when(
      data: (display) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FilledButton.icon(
                onPressed: () => _openForm(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Registrar egreso'),
              ),
            );
          }
          final e = list[i - 1];
          final alias = display.aliasFor(e);
          final isCreditCard = e.paymentType == 'credit_card';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('\$${formatCurrencyDisplay(e.amount, hideValues)}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    [
                      if (e.description != null && e.description!.isNotEmpty) e.description!,
                      formatDisplayDate(e.date.toLocal()),
                      alias,
                    ].join(' · '),
                  ),
                  if (isCreditCard) ...[
                    const SizedBox(height: 6),
                    _CreditCardBadge(),
                  ],
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, ref, e),
              ),
              onTap: () => _openForm(context, ref, edit: e),
            ),
          );
        },
      ),
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FilledButton.icon(
                onPressed: () => _openForm(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Registrar egreso'),
              ),
            );
          }
          final e = list[i - 1];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('\$${formatCurrencyDisplay(e.amount, hideValues)}'),
              subtitle: Text(formatDisplayDate(e.date.toLocal())),
              onTap: () => _openForm(context, ref, edit: e),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, ref, e),
              ),
            ),
          );
        },
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildFilterBar(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedExpenseDateFilterProvider);
    final paymentFilter = ref.watch(selectedExpensePaymentIdsFilterProvider);
    final asyncCards = ref.watch(creditCardsListProvider);
    final asyncMethods = ref.watch(paymentMethodsListProvider);
    const filters = [
      ExpenseDateFilter.today,
      ExpenseDateFilter.yesterday,
      ExpenseDateFilter.thisWeek,
      ExpenseDateFilter.last30Days,
      ExpenseDateFilter.currentMonth,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ...filters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f.label),
                  selected: selected.type == f.type,
                  onSelected: (_) => ref.read(selectedExpenseDateFilterProvider.notifier).state = f,
                ),
              )),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Rango personalizado'),
              selected: selected.type == ExpenseDateFilterType.custom,
              onSelected: (_) => _pickCustomRange(context, ref),
            ),
          ),
          asyncCards.when(
            data: (cards) => asyncMethods.when(
              data: (methods) {
                if (cards.isEmpty && methods.isEmpty) return const SizedBox.shrink();
                final n = paymentFilter.length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                    label: Text(n == 0 ? 'Tarjetas y cuentas' : 'Medios ($n)'),
                    selected: n > 0,
                    onSelected: (_) => _openPaymentFilterSheet(context, ref, cards, methods),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.outgoing_mail),
            tooltip: 'Enviar exportación por correo',
            onPressed: () => _sendExpenseExportEmail(context, ref),
          ),
        ],
      ),
    );
  }

  void _openPaymentFilterSheet(
    BuildContext context,
    WidgetRef ref,
    List<CreditCard> cards,
    List<PaymentMethod> methods,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.55;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filtrar por tarjeta o cuenta',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sin selección se muestran todos los egresos del periodo. Si marcas opciones, solo verás los cargados a esas tarjetas o cuentas.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, sheetRef, _) {
                    final selected = sheetRef.watch(selectedExpensePaymentIdsFilterProvider);
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxH),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (cards.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4, top: 4),
                              child: Text(
                                'Tarjetas de crédito',
                                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            for (final c in cards)
                              CheckboxListTile(
                                value: selected.contains(c.id),
                                onChanged: (v) {
                                  final next = Set<String>.from(selected);
                                  if (v == true) {
                                    next.add(c.id);
                                  } else {
                                    next.remove(c.id);
                                  }
                                  sheetRef.read(selectedExpensePaymentIdsFilterProvider.notifier).state = next;
                                },
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(c.alias),
                                secondary: const Icon(Icons.credit_card_outlined, size: 20),
                              ),
                          ],
                          if (methods.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4, top: 12),
                              child: Text(
                                'Cuentas de ahorro',
                                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            for (final m in methods)
                              CheckboxListTile(
                                value: selected.contains(m.id),
                                onChanged: (v) {
                                  final next = Set<String>.from(selected);
                                  if (v == true) {
                                    next.add(m.id);
                                  } else {
                                    next.remove(m.id);
                                  }
                                  sheetRef.read(selectedExpensePaymentIdsFilterProvider.notifier).state = next;
                                },
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(m.name),
                                secondary: const Icon(Icons.savings_outlined, size: 20),
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
          ),
        );
      },
    );
  }

  Future<void> _sendExpenseExportEmail(BuildContext context, WidgetRef ref) async {
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
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );

    try {
      await ref.read(expenseExportServiceProvider).sendExpenseExportEmail(window);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te enviamos el archivo por correo.')),
      );
    } catch (e, _) {
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

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (range != null) {
      ref.read(selectedExpenseDateFilterProvider.notifier).state = ExpenseDateFilter.custom(range);
    }
  }

  void _openForm(BuildContext context, WidgetRef ref, {Expense? edit}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(edit: edit),
      ),
    ).then((_) => ref.invalidate(expensesListProvider));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar este egreso?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(expenseRepositoryProvider).delete(e.id);
    ref.invalidate(expensesListProvider);
  }
}

class _CreditCardBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppThemeColors.primaryGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppThemeColors.primaryGreen.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.credit_card, size: 14, color: AppThemeColors.primaryGreen),
            const SizedBox(width: 4),
            Text(
              'Crédito',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppThemeColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
