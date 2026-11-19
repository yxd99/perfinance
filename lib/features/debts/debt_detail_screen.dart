import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/core/widgets/paid_stamp.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/models/debt_payment.dart';
import 'package:perfinance/data/models/mirrored_debt_payment.dart';
import 'package:perfinance/data/repositories/debt_payment_repository.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/data/repositories/mirrored_debt_repository.dart';
import 'package:perfinance/features/debts/debt_list_copy.dart';
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
      _mirroredPaymentsFuture = ref.read(mirroredDebtRepositoryProvider).paymentsFor(_debt.mirroredDebtId!);
      _paymentsFuture = Future.value([]);
    } else {
      _paymentsFuture = ref.read(debtPaymentRepositoryProvider).getByDebtId(_debt.id);
      _mirroredPaymentsFuture = Future.value([]);
    }
  }

  void _refreshPayments() {
    setState(() {
      if (_debt.isMirrored) {
        _mirroredPaymentsFuture = ref.read(mirroredDebtRepositoryProvider).paymentsFor(_debt.mirroredDebtId!);
      } else {
        _paymentsFuture = ref.read(debtPaymentRepositoryProvider).getByDebtId(_debt.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Deuda recibida: rama de solo lectura.
    if (_debt.isMirrored) {
      return _buildMirroredDetail(context);
    }

    final c = context.colors;
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
              icon: const Icon(CupertinoIcons.trash),
              tooltip: 'Eliminar deuda',
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
          final overdue = isDebtOverdue(DebtWithPaid(debt: _debt, paid: totalPaid), DateTime.now());
          final installmentsPaid = _debt.amountPerInstallment > 0
              ? (totalPaid / _debt.amountPerInstallment).floor()
              : 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (isPaid)
                _InfoBanner(
                  message: 'Esta deuda está marcada como pagada. Reactívala para registrar nuevos pagos.',
                  background: c.positiveSoft,
                  foreground: c.ink,
                ),
              if (isHidden)
                _InfoBanner(
                  message: 'Esta deuda está oculta. Reactívala para volver a operarla.',
                  background: c.track,
                  foreground: c.ink,
                ),
              _SectionHeader(
                'Resumen',
                trailing: switch (status) {
                  DebtStatus.paid => const PaidStamp(label: 'Pagada'),
                  DebtStatus.hidden => const _QuietTag(label: 'Oculta'),
                  DebtStatus.active => null,
                },
              ),
              _Group(
                children: [
                  _RowLabel('Valor total', '\$${formatCurrencyDisplay(_debt.totalAmount, hideValues)}'),
                  _RowLabel('Cuota', '\$${formatCurrencyDisplay(_debt.amountPerInstallment, hideValues)}'),
                  _RowLabel('Cuotas', '${_debt.numberOfInstallments}'),
                  _RowLabel('Cuotas pagadas', '$installmentsPaid'),
                  _RowLabel('Total pagado', '\$${formatCurrencyDisplay(totalPaid, hideValues)}'),
                  _RowLabel(
                    'Falta por pagar',
                    '\$${formatCurrencyDisplay(remaining, hideValues)}',
                    overdue: overdue,
                  ),
                  _DueDateRow(dueDate: _debt.dueDate, overdue: overdue),
                ],
              ),
              const SizedBox(height: 16),
              // Matriz de acciones según el estado.
              if (isActive) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _payDebt(context),
                        icon: const Icon(CupertinoIcons.checkmark_circle),
                        label: const Text('Pagar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _HideButton(onPressed: () => _hideDebt(context))),
                  ],
                ),
              ] else if (isPaid) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _reactivateDebt(context),
                        icon: const Icon(CupertinoIcons.arrow_counterclockwise),
                        label: const Text('Reactivar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _HideButton(onPressed: () => _hideDebt(context))),
                  ],
                ),
              ] else if (isHidden) ...[
                FilledButton.icon(
                  onPressed: () => _reactivateDebt(context),
                  icon: const Icon(CupertinoIcons.arrow_counterclockwise),
                  label: const Text('Reactivar'),
                ),
              ],
              if (isActive || isHidden) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: remaining <= 0 ? null : () => _payInstallment(context),
                        icon: const Icon(CupertinoIcons.creditcard),
                        label: const Text('Pagar cuota'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: remaining <= 0 ? null : () => _payCustom(context),
                        icon: const Icon(CupertinoIcons.pencil),
                        label: const Text('Otro monto'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const _SectionHeader('Historial de pagos'),
              _Group(
                children: payments.isEmpty
                    ? const [_EmptyRow('Todavía no registraste pagos.')]
                    : [
                        for (final p in payments)
                          _PaymentRow(
                            amount: '\$${formatCurrencyDisplay(p.amount, hideValues)}',
                            date: formatDisplayDate(p.date),
                            onDelete: () => _deletePayment(context, p),
                          ),
                      ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMirroredDetail(BuildContext context) {
    final c = context.colors;
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(_debt.name)),
      body: FutureBuilder<List<MirroredDebtPayment>>(
        future: _mirroredPaymentsFuture,
        builder: (context, snap) {
          final payments = snap.data ?? [];
          final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
          final remaining = _debt.totalAmount - totalPaid;
          final overdue = isDebtOverdue(DebtWithPaid(debt: _debt, paid: totalPaid), DateTime.now());

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _InfoBanner(message: 'Registrada por ${_debt.creditorEmail}', background: c.infoSoft, foreground: c.info),
              if (_debt.isRevoked)
                _InfoBanner(
                  message: 'Esta deuda fue cancelada por ${_debt.creditorEmail}',
                  background: c.track,
                  foreground: c.ink,
                ),
              const _SectionHeader('Resumen'),
              _Group(
                children: [
                  _RowLabel('Valor total', '\$${formatCurrencyDisplay(_debt.totalAmount, hideValues)}'),
                  _RowLabel('Total pagado', '\$${formatCurrencyDisplay(totalPaid, hideValues)}'),
                  _RowLabel(
                    'Falta por pagar',
                    '\$${formatCurrencyDisplay(remaining, hideValues)}',
                    overdue: overdue,
                  ),
                  _DueDateRow(dueDate: _debt.dueDate, overdue: overdue),
                ],
              ),
              // Eliminar solo cuando el acreedor la canceló.
              if (_debt.isRevoked) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _deleteMirroredDebt(context),
                  icon: Icon(CupertinoIcons.trash, color: c.danger),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.danger,
                    side: BorderSide(color: c.danger),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const _SectionHeader('Historial de pagos'),
              _Group(
                children: payments.isEmpty
                    ? const [_EmptyRow('Todavía no hay pagos registrados.')]
                    : [
                        // Sin eliminar: quien debe no borra pagos individuales.
                        for (final p in payments)
                          _PaymentRow(
                            amount: '\$${formatCurrencyDisplay(p.amount, hideValues)}',
                            date: formatDisplayDate(p.date),
                          ),
                      ],
              ),
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
        content: Text('¿Eliminar «${_debt.name}»? Esta deuda fue cancelada por el acreedor.'),
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
        content: Text('¿Marcar «${_debt.name}» como pagada?'),
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
        content: Text('¿Ocultar «${_debt.name}»? Puedes reactivarla desde el filtro Ocultas.'),
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
    await repo.insert(DebtPayment(id: const Uuid().v4(), debtId: _debt.id, amount: amount, date: DateTime.now()));
    if (mounted) {
      _refreshPayments();
      ref.invalidate(debtsListProvider);
      ref
          .read(syncServiceProvider)
          .pushPendingIfOnline()
          .catchError((Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'debts.push'));
    }
  }

  Future<void> _deleteDebt(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar deuda'),
        content: Text('¿Eliminar «${_debt.name}»? Se mantendrá el historial de pagos hasta la próxima sincronización.'),
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
      ref
          .read(syncServiceProvider)
          .pushPendingIfOnline()
          .catchError((Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'debts.push'));
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
      ref
          .read(syncServiceProvider)
          .pushPendingIfOnline()
          .catchError((Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'debts.push'));
    }
  }
}

/// Encabezado de sección de lista agrupada: mayúsculas, tinta suave.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: c.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.8),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Grupo inset sobre papel claro con líneas finas entre filas.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
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
    );
  }
}

class _QuietTag extends StatelessWidget {
  const _QuietTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.textMuted),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.textMuted)),
    );
  }
}

class _HideButton extends StatelessWidget {
  const _HideButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(CupertinoIcons.eye_slash),
      label: const Text('Ocultar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textMuted,
        side: BorderSide(color: c.divider),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message, required this.background, required this.foreground});
  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.label, this.value, {this.overdue = false});

  final String label;
  final String value;

  /// Lo que se debe va en tinta; el rojo queda solo para lo vencido.
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: t.bodyLarge?.copyWith(color: overdue ? c.danger : c.ink, fontWeight: overdue ? FontWeight.w600 : null),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: t.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: kTabularFigures,
                color: overdue ? c.danger : c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fecha máxima de pago; vencida, lo dice en palabras además del rojo.
class _DueDateRow extends StatelessWidget {
  const _DueDateRow({required this.dueDate, required this.overdue});

  final DateTime dueDate;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final date = formatDisplayDate(dueDate);
    return _RowLabel('Fecha máxima de pago', overdue ? 'Venció $date' : date, overdue: overdue);
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.amount, required this.date, this.onDelete});

  final String amount;
  final String date;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, onDelete == null ? 16 : 0, 4),
        child: Row(
          children: [
            Expanded(child: Text(date, style: t.bodyLarge)),
            Text(
              amount,
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontFeatures: kTabularFigures),
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(CupertinoIcons.trash, color: c.danger, size: 20),
                tooltip: 'Eliminar pago',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.colors.textMuted)),
    );
  }
}
