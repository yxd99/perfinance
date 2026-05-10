import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/app_empty_state.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payment_form_screen.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/savings/savings_provider.dart';

class AutomaticPaymentsScreen extends ConsumerWidget {
  const AutomaticPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(automaticPaymentsListProvider);
    final asyncDisplay = ref.watch(expensePaymentDisplayProvider);
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    return asyncList.when(
      data: (list) {
        if (list.isEmpty) {
          return AppEmptyState(
            icon: Icons.autorenew_outlined,
            message: 'No hay pagos automáticos.',
            actionLabel: 'Agregar pago automático',
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
                    label: const Text('Agregar pago automático'),
                  ),
                );
              }
              final p = list[i - 1];
              final alias = p.paymentType == 'credit_card'
                  ? (display.cardAliases[p.paymentRef] ?? 'Tarjeta')
                  : (display.methodNames[p.paymentRef] ?? 'Medio');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppThemeColors.primaryGreen.withValues(alpha: 0.2),
                    child: Icon(Icons.autorenew, color: AppThemeColors.primaryGreen),
                  ),
                  title: Text(p.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '\$${formatCurrencyDisplay(p.amount, hideValues)} · $alias · Día ${p.paymentDayOfMonth} · ${_capitalize(p.frequency)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AutomaticPaymentFormScreen(edit: p),
                    ),
                  ).then((_) {
                    ref.invalidate(automaticPaymentsListProvider);
                    ref.invalidate(expensesListProvider);
                  }),
                  onLongPress: () => _delete(context, ref, p),
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
                    label: const Text('Agregar pago automático'),
                  ),
                );
              }
              final p = list[i - 1];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(p.description),
                  subtitle: Text('Día ${p.paymentDayOfMonth} · ${_capitalize(p.frequency)}'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AutomaticPaymentFormScreen(edit: p),
                    ),
                  ).then((_) => ref.invalidate(automaticPaymentsListProvider)),
                ),
              );
            },
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorState(message: 'Error al cargar pagos automáticos.'),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  void _openForm(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AutomaticPaymentFormScreen()),
    ).then((_) {
      ref.invalidate(automaticPaymentsListProvider);
      ref.invalidate(expensesListProvider);
    });
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AutomaticPayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pago automático'),
        content: Text('¿Eliminar "${p.description}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(automaticPaymentRepositoryProvider).delete(p.id);
    ref.invalidate(automaticPaymentsListProvider);
  }
}
