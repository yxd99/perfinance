import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/receivables/receivable_notification_service.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';
import 'package:uuid/uuid.dart';

class ReceivableFormScreen extends ConsumerStatefulWidget {
  const ReceivableFormScreen({super.key, this.editReceivable});

  final Receivable? editReceivable;

  @override
  ConsumerState<ReceivableFormScreen> createState() => _ReceivableFormScreenState();
}

class _ReceivableFormScreenState extends ConsumerState<ReceivableFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();

  bool get _isEdit => widget.editReceivable != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final r = widget.editReceivable!;
      _nameController.text = r.debtorName;
      _descriptionController.text = r.description ?? '';
      _emailController.text = r.debtorEmail ?? '';
      _amountController.text = formatCurrency(r.totalAmount);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Editar cobro' : 'Nuevo cobro')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del responsable',
                hintText: 'Ej: Juan Pérez',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresá el nombre del responsable' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej: Préstamo para el carro',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (opcional)',
                hintText: 'Ej: juan@gmail.com',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final email = v.trim();
                if (!email.contains('@') || !email.contains('.')) {
                  return 'Email inválido. Verificá el formato.';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            Text(
              'Lo usamos para notificarle los cobros.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: 16),
            CurrencyTextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Monto total adeudado'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _save,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final total = parseCurrency(_amountController.text);
    if (total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe ser mayor a cero.')),
      );
      return;
    }
    final name = _nameController.text.trim();
    final descriptionText = _descriptionController.text.trim();
    final description = descriptionText.isEmpty ? null : descriptionText;
    final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();

    final repo = ref.read(receivableRepositoryProvider);

    if (_isEdit) {
      final r = widget.editReceivable!;
      await repo.update(Receivable(
        id: r.id,
        userId: r.userId,
        debtorName: name,
        debtorEmail: email,
        totalAmount: total,
        description: description,
        dueDate: r.dueDate,
        status: r.status,
        syncStatus: r.syncStatus,
        updatedAt: r.updatedAt,
        createdAt: r.createdAt,
      ));
    } else {
      final user = await ref.read(authStateProvider.future);
      if (user == null) return;
      final newReceivable = Receivable(
        id: const Uuid().v4(),
        userId: user.id,
        debtorName: name,
        debtorEmail: email,
        totalAmount: total,
        description: description,
      );
      await repo.insert(newReceivable);
      if (email != null && email.isNotEmpty) {
        try {
          await ref.read(receivableNotificationServiceProvider).notify(
                ReceivableNotificationPayload(
                  event: ReceivableNotificationEvent.created,
                  recipientEmail: email,
                  debtorName: name,
                  description: description,
                  totalAmount: total,
                  remainingBalance: total,
                  creditorEmail: user.email,
                ),
              );
        } catch (e, st) {
          // La deuda ya quedó guardada; solo falló el aviso por email.
          ErrorReporter.capture(e, st, operation: 'receivables.notify_created');
        }
      }
    }

    if (mounted) {
      ref.invalidate(receivablesListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
            (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'receivables.push'),
          );
      Navigator.pop(context);
    }
  }
}
