import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/models/debt_payment.dart';
import 'package:perfinance/data/models/mirrored_debt_payment.dart';
import 'package:perfinance/data/repositories/debt_payment_repository.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/data/repositories/mirrored_debt_repository.dart';
import 'package:perfinance/features/debts/debts_provider.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:uuid/uuid.dart';

class DebtDetailScreen extends ConsumerStatefulWidget {
  final Debt debt;

  const DebtDetailScreen({super.key, required this.debt});

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  late Debt _debt;
  late Future<List<DebtPayment>> _paymentsFuture;
  late Future<List<MirroredDebtPayment>> _mirroredPaymentsFuture;

  @override
  void initState() {
    super.initState();
    _debt = widget.debt;
    if (_debt.isMirrored) {
      _mirroredPaymentsFuture =
          ref.read(mirroredDebtRepositoryProvider).paymentsFor(_debt.mirroredDebtId!);
      _paymentsFuture = Future.value([]);
    } else {
      _paymentsFuture = ref.read(debtPaymentRepositoryProvider).getByDebtId(_debt.id);
      _mirroredPaymentsFuture = Future.value([]);
    }
  }

  void _refreshPayments() {
    setState(() {
      if (_debt.isMirrored) {
        _mirroredPaymentsFuture =
            ref.read(mirroredDebtRepositoryProvider).paymentsFor(_debt.mirroredDebtId!);
      } else {
        _paymentsFuture = ref.read(debtPaymentRepositoryProvider).getByDebtId(_debt.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mirrored debt — read-only branch
    if (_debt.isMirrored) {
      return _buildMirroredDetail(context);
    }

    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    final status = _debt.status;
    final isActive = status == DebtStatus.active;
    final isPaid = status == DebtStatus.paid;
    final isHidden = status == DebtStatus.hidden;

    return Scaffold(
      appBar: AppBar(
        title: Text(_debt.name),
        actions: [
          if (!isHidden)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteDebt(context),
            ),
        ],
      ),
      body: FutureBuilder<List<DebtPayment>>(
        future: _paymentsFuture,
        builder: (context, snap) {
          final payments = snap.data ?? [];
          final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
          final remaining = _debt.totalAmount - totalPaid;
          final installmentsPaid = _debt.amountPerInstallment > 0
              ? (totalPaid / _debt.amountPerInstallment).floor()
              : 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isPaid)
                _InfoBanner(
                  message: 'Esta deuda está marcada como pagada. Reactivala para registrar nuevos pagos.',
                  color: context.colors.accent,
                ),
              if (isHidden)
                _InfoBanner(
                  message: 'Esta deuda está oculta. Reactivala para volver a operarla.',
                  color: context.colors.textMuted,
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Resumen',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          _StatusBadge(status: _debt.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _RowLabel('Valor total', '\$${formatCurrencyDisplay(_debt.totalAmount, hideValues)}'),
                      _RowLabel('Cuota', '\$${formatCurrencyDisplay(_debt.amountPerInstallment, hideValues)}'),
                      _RowLabel('Cuotas', '${_debt.numberOfInstallments}'),
                      _RowLabel('Cuotas pagadas', '$installmentsPaid'),
                      _RowLabel('Total pagado', '\$${formatCurrencyDisplay(totalPaid, hideValues)}'),
                      _RowLabel('Falta por pagar', '\$${formatCurrencyDisplay(remaining, hideValues)}', isHighlight: remaining > 0),
                      const SizedBox(height: 8),
                      Text('Fecha máximo de pago: ${formatDisplayDate(_debt.dueDate)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Action matrix
              if (isActive) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _payDebt(context),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Pagar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _hideDebt(context),
                        icon: const Icon(Icons.visibility_off_outlined),
                        label: const Text('Ocultar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.textMuted,
                          side: BorderSide(color: context.colors.divider),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isPaid) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _reactivateDebt(context),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reactivar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _hideDebt(context),
                        icon: const Icon(Icons.visibility_off_outlined),
                        label: const Text('Ocultar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.textMuted,
                          side: BorderSide(color: context.colors.divider),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isHidden) ...[
                FilledButton.icon(
                  onPressed: () => _reactivateDebt(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reactivar'),
                ),
              ],
              if (isActive) ...[
                const SizedBox(height: 16),
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
              ],
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
                          backgroundColor: context.colors.accentSoft,
                          child: Icon(Icons.check, color: context.colors.accent, size: 20),
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

  Widget _buildMirroredDetail(BuildContext context) {
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_debt.name),
      ),
      body: FutureBuilder<List<MirroredDebtPayment>>(
        future: _mirroredPaymentsFuture,
        builder: (context, snap) {
          final payments = snap.data ?? [];
          final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
          final remaining = _debt.totalAmount - totalPaid;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info: creditor
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.infoSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.info.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Registrada por ${_debt.creditorEmail}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              // Revoked banner
              if (_debt.isRevoked)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.track,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.divider),
                  ),
                  child: Text(
                    'Esta deuda fue cancelada por ${_debt.creditorEmail}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              // Summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      _RowLabel('Valor total', '\$${formatCurrencyDisplay(_debt.totalAmount, hideValues)}'),
                      _RowLabel('Total pagado', '\$${formatCurrencyDisplay(totalPaid, hideValues)}'),
                      _RowLabel('Falta por pagar', '\$${formatCurrencyDisplay(remaining, hideValues)}', isHighlight: remaining > 0),
                      const SizedBox(height: 8),
                      Text('Fecha máximo de pago: ${formatDisplayDate(_debt.dueDate)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Delete button — only when revoked
              if (_debt.isRevoked)
                OutlinedButton.icon(
                  onPressed: () => _deleteMirroredDebt(context),
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                  ),
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
                          backgroundColor: context.colors.infoSoft,
                          child: Icon(Icons.check, color: context.colors.info, size: 20),
                        ),
                        title: Text('\$${formatCurrencyDisplay(p.amount, hideValues)}'),
                        subtitle: Text(formatDisplayDate(p.date)),
                        // NO delete button — debtor cannot delete individual payments
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteMirroredDebt(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar deuda recibida'),
        content: Text('¿Eliminar "${_debt.name}"? Esta deuda fue cancelada por el acreedor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(mirroredDebtRepositoryProvider).deleteByMirroredId(_debt.mirroredDebtId!);
    if (mounted) {
      ref.invalidate(debtsListProvider);
      ref.invalidate(filteredDebtsWithPaidProvider);
      Navigator.pop(context);
    }
  }

  Future<void> _payDebt(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como pagada'),
        content: Text('¿Marcar "${_debt.name}" como pagada?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pagar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(debtRepositoryProvider).payDebt(_debt.id);
    if (mounted) {
      ref.invalidate(debtsListProvider);
      ref.invalidate(filteredDebtsWithPaidProvider);
      final fresh = await ref.read(debtRepositoryProvider).getById(_debt.id);
      if (fresh != null && mounted) setState(() => _debt = fresh);
    }
  }

  Future<void> _reactivateDebt(BuildContext context) async {
    await ref.read(debtRepositoryProvider).reactivateDebt(_debt.id);
    if (mounted) {
      ref.invalidate(debtsListProvider);
      ref.invalidate(filteredDebtsWithPaidProvider);
      final fresh = await ref.read(debtRepositoryProvider).getById(_debt.id);
      if (fresh != null && mounted) setState(() => _debt = fresh);
    }
  }

  Future<void> _hideDebt(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ocultar deuda'),
        content: Text('¿Ocultar "${_debt.name}"? Podés reactivarla desde el filtro Ocultas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: OutlinedButton.styleFrom(foregroundColor: context.colors.textMuted),
            child: const Text('Ocultar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(debtRepositoryProvider).hideDebt(_debt.id);
    if (mounted) {
      ref.invalidate(debtsListProvider);
      ref.invalidate(filteredDebtsWithPaidProvider);
      final fresh = await ref.read(debtRepositoryProvider).getById(_debt.id);
      if (fresh != null && mounted) setState(() => _debt = fresh);
    }
  }

  Future<void> _payInstallment(BuildContext context) async {
    final amount = _debt.amountPerInstallment;
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
      debtId: _debt.id,
      amount: amount,
      date: DateTime.now(),
    ));
    if (mounted) {
      _refreshPayments();
      ref.invalidate(debtsListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
    }
  }

  Future<void> _deleteDebt(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar deuda'),
        content: Text('¿Eliminar "${_debt.name}"? Se mantendrá el historial de pagos hasta la próxima sincronización.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(debtRepositoryProvider).delete(_debt.id);
    if (mounted) {
      ref.invalidate(debtsListProvider);
      ref.invalidate(filteredDebtsWithPaidProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
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
      _refreshPayments();
      ref.invalidate(debtsListProvider);
      ref.invalidate(filteredDebtsWithPaidProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final DebtStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DebtStatus.active:
        return const SizedBox.shrink();
      case DebtStatus.paid:
        return _Pill(label: 'Pagada', color: context.colors.accent, textColor: context.colors.onAccent);
      case DebtStatus.hidden:
        return _Pill(
          label: 'Oculta',
          color: context.colors.track,
          textColor: context.colors.textMuted,
          borderColor: context.colors.divider,
        );
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.textColor, this.borderColor});
  final String label;
  final Color color;
  final Color textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message, required this.color});
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
    );
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
