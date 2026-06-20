import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/expense_form_screen.dart';

/// Pantalla que muestra los egresos de una tarjeta o medio de pago para un mes dado.
class DashboardAccountExpensesScreen extends ConsumerWidget {
  const DashboardAccountExpensesScreen({
    super.key,
    required this.alias,
    required this.paymentType,
    required this.paymentRef,
    required this.month,
  });

  final String alias;
  final String paymentType;
  final String paymentRef;
  final DateTime month;

  static const List<String> _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(expensesListProvider);
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    final monthLabel = '${_monthNames[month.month - 1]} ${month.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(alias),
      ),
      body: asyncList.when(
        data: (all) {
          final start = DateTime(month.year, month.month, 1);
          final end = month.month == 12
              ? DateTime(month.year + 1, 1, 1)
              : DateTime(month.year, month.month + 1, 1);
          final list = all
              .where((e) =>
                  e.paymentType == paymentType &&
                  e.paymentRef == paymentRef &&
                  !e.date.isBefore(start) &&
                  e.date.isBefore(end))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          final total = list.fold<double>(0, (s, e) => s + e.amount);

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Sin egresos en $monthLabel',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '$monthLabel · Total: \$${formatCurrencyDisplay(total, hideValues)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppThemeColors.primaryGreen,
                      ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final e = list[i];
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
                              ].join(' · '),
                            ),
                            if (isCreditCard)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppThemeColors.primaryGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Crédito',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppThemeColors.primaryGreen,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpenseFormScreen(edit: e),
                            ),
                          ).then((_) => ref.invalidate(expensesListProvider));
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar los egresos',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
