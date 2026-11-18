import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/core/widgets/paid_stamp.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/receivables/receivable_actions.dart';
import 'package:perfinance/features/receivables/receivable_form_screen.dart';
import 'package:perfinance/features/receivables/receivable_notification_service.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';
import 'package:perfinance/features/receivables/register_payment_bottom_sheet.dart';
import 'package:perfinance/features/receivables/widgets/inset_list_group.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final isActive = _receivable.status == ReceivableStatus.active;
    final isSettled = _receivable.status == ReceivableStatus.settled;

    return Scaffold(
      appBar: AppBar(
        title: Text(_receivable.debtorName),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(CupertinoIcons.pencil),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReceivableFormScreen(editReceivable: _receivable)),
              );
              await _reload();
            },
          ),
          IconButton(tooltip: 'Eliminar', icon: const Icon(CupertinoIcons.trash), onPressed: _deleteReceivable),
        ],
      ),
      body: FutureBuilder<List<ReceivablePayment>>(
        future: _paymentsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No se pudieron cargar los cobros. Volvé a abrir esta deuda.',
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(color: c.textMuted),
                ),
              ),
            );
          }
          final payments = snap.data ?? [];
          final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
          final remaining = _receivable.totalAmount - totalPaid;
          final progress = (_receivable.totalAmount > 0 ? (totalPaid / _receivable.totalAmount).clamp(0.0, 1.0) : 0.0)
              .toDouble();
          final statusLine = switch (_receivable.status) {
            ReceivableStatus.writtenOff => 'Incobrable. No suma al total por cobrar.',
            ReceivableStatus.hidden => 'Cancelada. Podés reactivarla cuando quieras.',
            ReceivableStatus.settled => 'Cobrada en su totalidad. Reactivala para registrar nuevos cobros.',
            ReceivableStatus.active => null,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              InsetListGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    remaining > 0 && isActive ? 'Te falta cobrar' : 'Monto total',
                                    style: t.labelLarge?.copyWith(color: c.textMuted),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '\$${formatCurrency(remaining > 0 && isActive ? remaining : _receivable.totalAmount)}',
                                    style: t.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: kTabularFigures,
                                      color: remaining > 0 && isActive ? c.warning : c.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSettled) const PaidStamp(label: 'Saldada'),
                          ],
                        ),
                        if (statusLine != null) ...[
                          const SizedBox(height: 6),
                          Text(statusLine, style: t.bodySmall?.copyWith(color: c.textMuted)),
                        ],
                        const SizedBox(height: 12),
                        ExcludeSemantics(
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: c.track,
                            valueColor: AlwaysStoppedAnimation(c.accent),
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(progress * 100).round()}% cobrado',
                          style: t.bodySmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures),
                        ),
                      ],
                    ),
                  ),
                  _ValueRow('Monto total', '\$${formatCurrency(_receivable.totalAmount)}'),
                  _ValueRow('Total cobrado', '\$${formatCurrency(totalPaid)}'),
                  if (isActive)
                    _ValueRow(
                      'Falta',
                      remaining <= 0 ? 'Cobrado al 100%' : '\$${formatCurrency(remaining)}',
                      color: remaining <= 0 ? c.positive : c.warning,
                    ),
                  if (_receivable.description?.trim().isNotEmpty ?? false)
                    _ValueRow('Descripción', _receivable.description!.trim(), tabular: false),
                  if (_receivable.debtorEmail != null) _ValueRow('Email', _receivable.debtorEmail!, tabular: false),
                ],
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
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => _settleInFull(remaining),
                      icon: const Icon(CupertinoIcons.checkmark_circle, size: 18),
                      label: Text('Cobrar todo (\$${formatCurrency(remaining)})'),
                    ),
                    if (_receivable.debtorEmail != null && _receivable.debtorEmail!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: _sendingReminder ? null : _sendReminder,
                        icon: _sendingReminder
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                              )
                            : const Icon(CupertinoIcons.paperplane, size: 18),
                        label: Text(_sendingReminder ? 'Enviando...' : 'Enviar recordatorio'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: c.textMuted, minimumSize: const Size.fromHeight(44)),
                      onPressed: _cancelReceivable,
                      child: const Text('Cancelar deuda'),
                    ),
                  ],
                ),
              if (isActive && remaining <= 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: c.warningSoft, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        'El saldo llegó a \$0. ¿La marcás como cobrada?',
                        style: t.bodyMedium?.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _markAsSettled, child: const Text('Marcar como cobrada')),
                  ],
                ),
              if (isSettled) FilledButton(onPressed: _reactivate, child: const Text('Reactivar')),
              const InsetSectionHeader('Historial de cobros'),
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Todavía no registraste cobros.', style: t.bodyMedium?.copyWith(color: c.textMuted)),
                )
              else
                InsetListGroup(
                  children: [
                    for (final p in payments)
                      _PaymentRow(
                        payment: p,
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
                        onDelete: () => _deletePayment(p),
                      ),
                  ],
                ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Podés enviar otro recordatorio en 24 horas.')));
        return;
      }
    }

    final payRepo = ref.read(receivablePaymentRepositoryProvider);
    final payments = await payRepo.getByReceivableId(_receivable.id);
    final remaining = _receivable.totalAmount - payments.fold<double>(0, (s, p) => s + p.amount);

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar recordatorio'),
        content: Text(
          'Le vamos a enviar un email automático a "$email" '
          'con el saldo pendiente de \$${formatCurrency(remaining)}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sendingReminder = true);
    try {
      await ref
          .read(receivableNotificationServiceProvider)
          .notify(
            ReceivableNotificationPayload(
              event: ReceivableNotificationEvent.reminder,
              recipientEmail: email,
              debtorName: _receivable.debtorName,
              description: _receivable.description,
              totalAmount: _receivable.totalAmount,
              remainingBalance: remaining,
              creditorEmail: Supabase.instance.client.auth.currentUser?.email,
              receivableId: _receivable.id,
            ),
          );

      await prefs.setString(lastSentKey, DateTime.now().toIso8601String());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recordatorio enviado.')));
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'receivables.send_reminder', details: {'receivable_id': _receivable.id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo enviar el recordatorio. Revisá tu conexión y probá de nuevo.',
            style: TextStyle(color: context.colors.onDanger),
          ),
          backgroundColor: context.colors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingReminder = false);
    }
  }

  Future<void> _cancelReceivable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar deuda'),
        content: Text('¿Cancelás la deuda de "${_receivable.debtorName}"? Podés reactivarla después.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar deuda')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(receivableRepositoryProvider).hide(_receivable.id);
      ref.invalidate(receivablesListProvider);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _deleteReceivable() async {
    final deleted = await confirmAndDeleteReceivable(context, _receivable);
    if (deleted && mounted) Navigator.pop(context);
  }

  /// «Cobrar todo» vive acá (antes era el deslizamiento de la fila en la lista,
  /// que ahora elimina como en las demás listas).
  Future<void> _settleInFull(double remaining) async {
    final saved = await confirmAndSettleInFull(context, _receivable, remaining: remaining);
    if (saved) await _reload();
  }

  Future<void> _deletePayment(ReceivablePayment p) async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cobro'),
        content: Text('¿Eliminás el cobro de \$${formatCurrency(p.amount)} del ${formatDisplayDate(p.date)}?'),
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
    if (ok == true) {
      await ref.read(receivablePaymentRepositoryProvider).delete(p.id);
      final updatedPayments = await ref.read(receivablePaymentRepositoryProvider).getByReceivableId(_receivable.id);
      final newRemaining = _receivable.totalAmount - updatedPayments.fold(0.0, (s, pay) => s + pay.amount);
      if (_receivable.debtorEmail != null) {
        try {
          await ref
              .read(receivableNotificationServiceProvider)
              .notify(
                ReceivableNotificationPayload(
                  event: ReceivableNotificationEvent.paymentDeleted,
                  recipientEmail: _receivable.debtorEmail!,
                  debtorName: _receivable.debtorName,
                  description: _receivable.description,
                  totalAmount: _receivable.totalAmount,
                  remainingBalance: newRemaining,
                  paymentAmount: p.amount,
                  paymentDate: p.date,
                  creditorEmail: Supabase.instance.client.auth.currentUser?.email,
                ),
              );
        } catch (e, st) {
          // El cobro ya se borró; solo falló el aviso por email.
          ErrorReporter.capture(
            e,
            st,
            operation: 'receivables.notify_payment_deleted',
            details: {'receivable_id': _receivable.id},
          );
        }
      }
      await _reload();
      ref.invalidate(receivablesListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
            (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'receivables.push'),
          );
    }
  }
}

/// Fila de cobro: fecha a la izquierda, monto a la derecha; tocarla edita.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onEdit, required this.onDelete});

  final ReceivablePayment payment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onEdit,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(formatDisplayDate(payment.date), style: t.bodyLarge?.copyWith(color: c.ink)),
              ),
              Text(
                '\$${formatCurrency(payment.amount)}',
                style: t.titleSmall?.copyWith(color: c.ink, fontWeight: FontWeight.w700, fontFeatures: kTabularFigures),
              ),
              IconButton(
                tooltip: 'Eliminar cobro',
                icon: Icon(CupertinoIcons.trash, size: 20, color: c.danger),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value, {this.color, this.tabular = true});

  final String label;
  final String value;
  final Color? color;
  final bool tabular;

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
            Text(label, style: t.bodyLarge?.copyWith(color: c.textMuted)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: t.titleSmall?.copyWith(
                  color: color ?? c.ink,
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabular ? kTabularFigures : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
