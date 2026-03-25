import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/debt.dart';
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
                label: 'Todas',
                selected: filter == DebtListFilter.all,
                onTap: () => ref.read(debtListFilterProvider.notifier).state = DebtListFilter.all,
              ),
              const SizedBox(width: 8),
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
            ],
          ),
        ),
        Expanded(
          child: asyncList.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No hay deudas que coincidan.'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _openForm(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar deuda'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  return _DebtCard(
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
                  );
                },
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
                      UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.debtsLoadFailed),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (item.isPaid)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppThemeColors.primaryGreen,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Text(
                  'Pagada',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.fromLTRB(20, 12, item.isPaid ? 72 : 20, 12),
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
                  'Vence: ${debt.dueDate.day}/${debt.dueDate.month}/${debt.dueDate.year}',
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
