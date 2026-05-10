import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/models/debt_payment.dart';
import 'package:perfinance/data/repositories/debt_payment_repository.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/features/debts/debts_provider.dart';
import 'package:uuid/uuid.dart';

class DebtDetailScreen extends ConsumerStatefulWidget {
  final Debt debt;

  const DebtDetailScreen({super.key, required this.debt});

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.debt.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteDebt(context),
          ),
        ],
      ),
      body: FutureBuilder<List<DebtPayment>>(
        future: ref.read(debtPaymentRepositoryProvider).getByDebtId(widget.debt.id),
        builder: (context, snap) {
          final payments = snap.data ?? [];
          final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
          final remaining = widget.debt.totalAmount - totalPaid;
          final installmentsPaid = widget.debt.amountPerInstallment > 0
              ? (totalPaid / widget.debt.amountPerInstallment).floor()
              : 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Resumen', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      _RowLabel('Valor total', '\$${formatCurrencyDisplay(widget.debt.totalAmount, hideValues)}'),
                      _RowLabel('Cuota', '\$${formatCurrencyDisplay(widget.debt.amountPerInstallment, hideValues)}'),
                      _RowLabel('Cuotas', '${widget.debt.numberOfInstallments}'),
                      _RowLabel('Cuotas pagadas', '$installmentsPaid'),
                      _RowLabel('Total pagado', '\$${formatCurrencyDisplay(totalPaid, hideValues)}'),
                      _RowLabel('Falta por pagar', '\$${formatCurrencyDisplay(remaining, hideValues)}', isHighlight: remaining > 0),
                      const SizedBox(height: 8),
                      Text('Fecha máximo de pago: ${formatDisplayDate(widget.debt.dueDate)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: remaining <= 0 ? null : () => _payInstallment(context),
                      icon: const Icon(Icons.payment),
                      label: const Text('Pagar cuota'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: remaining <= 0 ? null : () => _payCustom(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('Monto personalizado'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Historial de pagos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (payments.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Aún no hay pagos registrados.')))
              else
                ...payments.map((p) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppThemeColors.primaryGreen.withValues(alpha: 0.2),
                          child: Icon(Icons.check, color: AppThemeColors.primaryGreen, size: 20),
                        ),
                        title: Text('\$${formatCurrencyDisplay(p.amount, hideValues)}'),
                        subtitle: Text(formatDisplayDate(p.date)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                          tooltip: 'Eliminar pago',
                          onPressed: () => _deletePayment(context, p),
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _payInstallment(BuildContext context) async {
    final amount = widget.debt.amountPerInstallment;
    if (amount <= 0) return;
    await _recordPayment(context, amount);
  }

  Future<void> _payCustom(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar monto personalizado'),
        content: CurrencyTextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Monto'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Registrar pago'),
          ),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    final amount = parseCurrency(c.text);
    if (amount == null || amount <= 0) return;
    await _recordPayment(context, amount);
  }

  Future<void> _recordPayment(BuildContext context, double amount) async {
    final repo = ref.read(debtPaymentRepositoryProvider);
    await repo.insert(DebtPayment(
      id: const Uuid().v4(),
      debtId: widget.debt.id,
      amount: amount,
      date: DateTime.now(),
    ));
    if (mounted) {
      setState(() {});
      ref.invalidate(debtsListProvider);
    }
  }

  Future<void> _deleteDebt(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar deuda'),
        content: Text('¿Eliminar "${widget.debt.name}"? Se mantendrá el historial de pagos hasta la próxima sincronización.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(debtRepositoryProvider).delete(widget.debt.id);
    if (mounted) {
      ref.invalidate(debtsListProvider);
      ref.invalidate(filteredDebtsWithPaidProvider);
      Navigator.pop(context);
    }
  }

  Future<void> _deletePayment(BuildContext context, DebtPayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pago'),
        content: Text(
          '¿Eliminar el pago de \$${formatCurrencyDisplay(p.amount, ref.read(hideValuesProvider).value ?? false)} del ${formatDisplayDate(p.date)}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(debtPaymentRepositoryProvider).delete(p.id);
    if (mounted) {
      setState(() {});
      ref.invalidate(debtsListProvider);
      ref.invalidate(filteredDebtsWithPaidProvider);
    }
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.label, this.value, {this.isHighlight = false});

  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isHighlight ? FontWeight.w700 : null, color: isHighlight ? Theme.of(context).colorScheme.error : null)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: isHighlight ? Theme.of(context).colorScheme.error : null)),
        ],
      ),
    );
  }
}
