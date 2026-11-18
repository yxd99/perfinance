import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/receivables/receivable_form_screen.dart';
import 'package:perfinance/features/receivables/receivable_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';
import 'package:perfinance/features/receivables/register_payment_bottom_sheet.dart';

class ReceivableDetailScreen extends ConsumerStatefulWidget {
  const ReceivableDetailScreen({super.key, required this.receivable});

  final Receivable receivable;

  @override
  ConsumerState<ReceivableDetailScreen> createState() => _ReceivableDetailScreenState();
}

class _ReceivableDetailScreenState extends ConsumerState<ReceivableDetailScreen> {
  late Receivable _receivable;
  late Future<List<ReceivablePayment>> _paymentsFuture;
  bool _sendingReminder = false;

  @override
  void initState() {
    super.initState();
    _receivable = widget.receivable;
    _paymentsFuture = _loadPayments();
  }

  Future<List<ReceivablePayment>> _loadPayments() =>
      ref.read(receivablePaymentRepositoryProvider).getByReceivableId(_receivable.id);

  Future<void> _reload() async {
    final payRepo = ref.read(receivablePaymentRepositoryProvider);
    final receivableRepo = ref.read(receivableRepositoryProvider);

    final results = await Future.wait([
      payRepo.getByReceivableId(_receivable.id),
      receivableRepo.getById(_receivable.id),
    ]);

    if (!mounted) return;
    final payments = results[0] as List<ReceivablePayment>;
    final updated = results[1] as Receivable?;
    setState(() {
      _paymentsFuture = Future.value(payments);
      if (updated != null) _receivable = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _receivable.status == ReceivableStatus.active;
    final isSettled = _receivable.status == ReceivableStatus.settled;

    return Scaffold(
      appBar: AppBar(
        title: Text(_receivable.debtorName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceivableFormScreen(editReceivable: _receivable),
                ),
              );
              await _reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteReceivable(context),
          ),
        ],
      ),
      body: FutureBuilder<List<ReceivablePayment>>(
        future: _paymentsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final payments = snap.data ?? [];
          final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
          final remaining = _receivable.totalAmount - totalPaid;
          final progress = (_receivable.totalAmount > 0
                  ? (totalPaid / _receivable.totalAmount).clamp(0.0, 1.0)
                  : 0.0)
              .toDouble();
          final remainingLabel = remaining <= 0 ? 'Cobrado al 100%' : '\$${formatCurrency(remaining)}';
          final remainingColor = remaining <= 0 ? context.colors.positive : context.colors.warning;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isSettled)
                _InfoBanner(
                  message: 'Esta deuda fue cobrada en su totalidad. Reactivala para registrar nuevos cobros.',
                  color: context.colors.positive,
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
                          _StatusBadge(status: _receivable.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _RowLabel('Monto total', '\$${formatCurrency(_receivable.totalAmount)}'),
                      _RowLabel('Total cobrado', '\$${formatCurrency(totalPaid)}'),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: context.colors.track,
                        valueColor: AlwaysStoppedAnimation(context.colors.accent),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            remaining <= 0 ? remainingLabel : 'Falta: $remainingLabel',
                            style: TextStyle(
                              color: remainingColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text('${(progress * 100).round()}%', style: TextStyle(color: context.colors.textMuted)),
                        ],
                      ),
                      if (_receivable.debtorEmail != null) ...[
                        const SizedBox(height: 8),
                        _RowLabel('Email', _receivable.debtorEmail!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isActive && remaining > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: () async {
                        await showRegisterPaymentSheet(
                          context,
                          ref,
                          receivable: _receivable,
                          remainingBalance: remaining,
                        );
                
                        await _reload();
                      },
                      child: const Text('Registrar cobro'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: context.colors.textMuted),
                      onPressed: () => _cancelReceivable(context),
                      child: const Text('Cancelar deuda'),
                    ),
                    if (_receivable.debtorEmail != null && _receivable.debtorEmail!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _sendingReminder ? null : _sendReminder,
                        icon: _sendingReminder
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.colors.textMuted,
                                ),
                              )
                            : const Icon(Icons.send_outlined, size: 18),
                        label: Text(_sendingReminder ? 'Enviando...' : 'Enviar recordatorio'),
                      ),
                    ],
                  ],
                ),
              if (isActive && remaining <= 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.warningSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('El saldo llegó a \$0. ¿Querés marcarla como cobrada?'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => _markAsSettled(),
                      child: const Text('Marcar como cobrada'),
                    ),
                  ],
                ),
              if (isSettled)
                FilledButton(
                  onPressed: () => _reactivate(),
                  child: const Text('Reactivar'),
                ),
              const SizedBox(height: 24),
              Text(
                'Historial de cobros',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Divider(),
              if (payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('Aún no hay cobros registrados.')),
                ),
              ...payments.map((p) => _PaymentTile(
                    payment: p,
                    receivable: _receivable,
                    remaining: remaining,
                    onEdit: () async {
                      await showRegisterPaymentSheet(
                        context,
                        ref,
                        receivable: _receivable,
                        remainingBalance: remaining,
                        editPayment: p,
                      );
                      await _reload();
                    },
                    onDelete: () => _deletePayment(context, p, remaining),
                  )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _markAsSettled() async {
    await ref.read(receivableRepositoryProvider).settle(_receivable.id);
    await _reload();
    ref.invalidate(receivablesListProvider);
  }

  Future<void> _reactivate() async {
    await ref.read(receivableRepositoryProvider).reactivate(_receivable.id);
    await _reload();
    ref.invalidate(receivablesListProvider);
  }

  Future<void> _sendReminder() async {
    final email = _receivable.debtorEmail;
    if (email == null || email.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final lastSentKey = 'reminder_last_${_receivable.id}';
    final lastSent = prefs.getString(lastSentKey);
    if (lastSent != null) {
      final lastSentDate = DateTime.tryParse(lastSent);
      if (lastSentDate != null && DateTime.now().difference(lastSentDate).inHours < 24) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Podés enviar otro recordatorio en 24 horas.'),
          ),
        );
        return;
      }
    }

    final payRepo = ref.read(receivablePaymentRepositoryProvider);
    final payments = await payRepo.getByReceivableId(_receivable.id);
    final remaining = _receivable.totalAmount - payments.fold<double>(0, (s, p) => s + p.amount);

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enviar recordatorio'),
        content: Text(
          'Se enviará un email automático a "$email" '
          'informando el saldo pendiente de \$${formatCurrency(remaining)}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sendingReminder = true);
    try {
      await ref.read(receivableNotificationServiceProvider).notify(
            ReceivableNotificationPayload(
              event: ReceivableNotificationEvent.reminder,
              recipientEmail: email,
              debtorName: _receivable.debtorName,
              totalAmount: _receivable.totalAmount,
              remainingBalance: remaining,
              creditorEmail: Supabase.instance.client.auth.currentUser?.email,
              receivableId: _receivable.id,
            ),
          );

      await prefs.setString(lastSentKey, DateTime.now().toIso8601String());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recordatorio enviado', style: TextStyle(color: context.colors.onAccent)),
          backgroundColor: context.colors.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar: $e', style: TextStyle(color: context.colors.onDanger)),
          backgroundColor: context.colors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingReminder = false);
    }
  }

  Future<void> _cancelReceivable(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar deuda'),
        content: Text('¿Cancelar la deuda de "${_receivable.debtorName}"? Podés reactivarla después.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: context.colors.textMuted),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar deuda'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(receivableRepositoryProvider).hide(_receivable.id);
      if (mounted) Navigator.pop(context);
      ref.invalidate(receivablesListProvider);
    }
  }

  Future<void> _deleteReceivable(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar deudor'),
        content: Text(
            '¿Eliminar a "${_receivable.debtorName}" y todo su historial de cobros? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(receivableRepositoryProvider).delete(_receivable.id);
      ref.invalidate(receivablesListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _deletePayment(BuildContext context, ReceivablePayment p, double remaining) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cobro'),
        content: Text(
            '¿Eliminar el cobro de \$${formatCurrency(p.amount)} del ${formatDisplayDate(p.date)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(receivablePaymentRepositoryProvider).delete(p.id);
      final updatedPayments =
          await ref.read(receivablePaymentRepositoryProvider).getByReceivableId(_receivable.id);
      final newRemaining =
          _receivable.totalAmount - updatedPayments.fold(0.0, (s, pay) => s + pay.amount);
      if (_receivable.debtorEmail != null) {
        try {
          await ref.read(receivableNotificationServiceProvider).notify(ReceivableNotificationPayload(
            event: ReceivableNotificationEvent.paymentDeleted,
            recipientEmail: _receivable.debtorEmail!,
            debtorName: _receivable.debtorName,
            totalAmount: _receivable.totalAmount,
            remainingBalance: newRemaining,
            paymentAmount: p.amount,
            paymentDate: p.date,
            creditorEmail: Supabase.instance.client.auth.currentUser?.email,
          ));
        } catch (_) {}
      }
      await _reload();
      ref.invalidate(receivablesListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
    }
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.receivable,
    required this.remaining,
    required this.onEdit,
    required this.onDelete,
  });

  final ReceivablePayment payment;
  final Receivable receivable;
  final double remaining;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: context.colors.accentSoft,
        child: Icon(Icons.check, color: context.colors.accent),
      ),
      title: Text('\$${formatCurrency(payment.amount)}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(formatDisplayDate(payment.date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
            onPressed: onDelete,
          ),
        ],
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ReceivableStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ReceivableStatus.settled => _Pill(label: 'Cobrada', color: context.colors.positive),
      ReceivableStatus.hidden => _Pill(label: 'Cancelada', color: context.colors.textMuted),
      ReceivableStatus.writtenOff => _Pill(label: 'Incobrable', color: context.colors.textMuted),
      ReceivableStatus.active => const SizedBox.shrink(),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.colors.textMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
