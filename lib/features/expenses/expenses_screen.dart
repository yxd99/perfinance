import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/expense_date_filter.dart';
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Total egresos: \$${formatCurrencyDisplay(total, hideValues)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Expanded(
                    child: _buildList(context, ref, list, asyncDisplay, hideValues),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.expensesLoadFailed),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No hay egresos.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Registrar egreso'),
            ),
          ],
        ),
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
                      '${e.date.toLocal().day}/${e.date.toLocal().month}/${e.date.toLocal().year}',
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
              subtitle: Text('${e.date.toLocal().day}/${e.date.toLocal().month}/${e.date.toLocal().year}'),
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
    const filters = [
      ExpenseDateFilter.today,
      ExpenseDateFilter.yesterday,
      ExpenseDateFilter.thisWeek,
      ExpenseDateFilter.last15Days,
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
        ],
      ),
    );
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
