import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();

  bool get _isEdit => widget.editReceivable != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final r = widget.editReceivable!;
      _nameController.text = r.debtorName;
      _emailController.text = r.debtorEmail ?? '';
      _amountController.text = formatCurrency(r.totalAmount);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Editar deuda' : 'Nueva deuda')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre o descripción',
                hintText: 'Ej: Juan Pérez, préstamo...',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un nombre' : null,
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
              'Se usará para notificarle los cobros.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            CurrencyTextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Monto total adeudado'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Guardar')),
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
      );
      await repo.insert(newReceivable);
      if (email != null && email.isNotEmpty) {
        try {
          await ref.read(receivableNotificationServiceProvider).notify(
                ReceivableNotificationPayload(
                  event: ReceivableNotificationEvent.created,
                  recipientEmail: email,
                  debtorName: name,
                  totalAmount: total,
                  remainingBalance: total,
                  creditorEmail: user.email,
                ),
              );
        } catch (_) {}
      }
    }

    if (mounted) {
      ref.invalidate(receivablesListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
      Navigator.pop(context);
    }
  }
}
