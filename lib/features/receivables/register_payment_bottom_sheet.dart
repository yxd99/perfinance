import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/features/receivables/receivable_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:uuid/uuid.dart';

Future<void> showRegisterPaymentSheet(
  BuildContext context,
  WidgetRef ref, {
  required Receivable receivable,
  required double remainingBalance,
  ReceivablePayment? editPayment,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _RegisterPaymentSheet(
      receivable: receivable,
      remainingBalance: remainingBalance,
      editPayment: editPayment,
    ),
  );
}

class _RegisterPaymentSheet extends ConsumerStatefulWidget {
  const _RegisterPaymentSheet({
    required this.receivable,
    required this.remainingBalance,
    this.editPayment,
  });

  final Receivable receivable;
  final double remainingBalance;
  final ReceivablePayment? editPayment;

  @override
  ConsumerState<_RegisterPaymentSheet> createState() => _RegisterPaymentSheetState();
}

class _RegisterPaymentSheetState extends ConsumerState<_RegisterPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  late DateTime _date;

  bool get _isEdit => widget.editPayment != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.editPayment!;
      _amountController.text = formatCurrency(p.amount);
      _date = p.date;
    } else {
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.track,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEdit ? 'Editar cobro' : 'Registrar cobro',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            CurrencyTextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Monto cobrado'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 56,
              title: const Text('Fecha del cobro'),
              subtitle: Text(formatDisplayDate(_date)),
              trailing: Icon(CupertinoIcons.calendar, color: context.colors.accent),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? 'Guardar cambios' : 'Guardar cobro'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseCurrency(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe ser mayor a cero.')),
      );
      return;
    }

    final payRepo = ref.read(receivablePaymentRepositoryProvider);
    final notifService = ref.read(receivableNotificationServiceProvider);

    try {
      if (_isEdit) {
        final existing = widget.editPayment!;
        await payRepo.update(ReceivablePayment(
          id: existing.id,
          receivableId: existing.receivableId,
          amount: amount,
          date: _date,
          note: existing.note,
          syncStatus: existing.syncStatus,
          updatedAt: existing.updatedAt,
          createdAt: existing.createdAt,
        ));
        final updatedPayments = await payRepo.getByReceivableId(widget.receivable.id);
        final newRemaining = widget.receivable.totalAmount -
            updatedPayments.fold(0.0, (s, p) => s + p.amount);
        if (widget.receivable.debtorEmail != null) {
          try {
            await notifService.notify(ReceivableNotificationPayload(
              event: ReceivableNotificationEvent.paymentEdited,
              recipientEmail: widget.receivable.debtorEmail!,
              debtorName: widget.receivable.debtorName,
              totalAmount: widget.receivable.totalAmount,
              remainingBalance: newRemaining,
              paymentAmount: amount,
              paymentDate: _date,
              creditorEmail: Supabase.instance.client.auth.currentUser?.email,
            ));
          } catch (e, st) {
            // El cobro ya quedó guardado; solo falló el aviso por email.
            ErrorReporter.capture(
              e,
              st,
              operation: 'receivables.notify_payment_edited',
              details: {'receivable_id': widget.receivable.id},
            );
          }
        }
      } else {
        final newPayment = ReceivablePayment(
          id: const Uuid().v4(),
          receivableId: widget.receivable.id,
          amount: amount,
          date: _date,
        );
        await payRepo.insert(newPayment);
        final updatedPayments = await payRepo.getByReceivableId(widget.receivable.id);
        final newRemaining = widget.receivable.totalAmount -
            updatedPayments.fold(0.0, (s, p) => s + p.amount);
        if (widget.receivable.debtorEmail != null) {
          try {
            await notifService.notify(ReceivableNotificationPayload(
              event: ReceivableNotificationEvent.paymentRecorded,
              recipientEmail: widget.receivable.debtorEmail!,
              debtorName: widget.receivable.debtorName,
              totalAmount: widget.receivable.totalAmount,
              remainingBalance: newRemaining,
              paymentAmount: amount,
              paymentDate: _date,
              creditorEmail: Supabase.instance.client.auth.currentUser?.email,
            ));
          } catch (e, st) {
            // El cobro ya quedó guardado; solo falló el aviso por email.
            ErrorReporter.capture(
              e,
              st,
              operation: 'receivables.notify_payment_recorded',
              details: {'receivable_id': widget.receivable.id},
            );
          }
        }
      }

      if (mounted) {
        // Capturar ScaffoldMessenger y el messenger ANTES de hacer pop.
        final messenger = ScaffoldMessenger.of(context);
        final successMsg = widget.receivable.debtorEmail != null
            ? 'Cobro registrado. Le avisamos a ${widget.receivable.debtorEmail}.'
            : 'Cobro registrado.';

        ref.invalidate(receivablesListProvider);
        Navigator.pop(context);

        messenger.showSnackBar(SnackBar(content: Text(successMsg)));

        ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message, style: TextStyle(color: context.colors.onDanger)),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } catch (e, st) {
      ErrorReporter.capture(
        e,
        st,
        operation: 'receivables.save_payment',
        details: {'receivable_id': widget.receivable.id, 'editing': _isEdit},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el cobro. Probá de nuevo.', style: TextStyle(color: context.colors.onDanger)),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    }
  }
}
