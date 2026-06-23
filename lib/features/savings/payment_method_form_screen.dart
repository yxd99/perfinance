import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/data/repositories/payment_method_repository.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:uuid/uuid.dart';

class PaymentMethodFormScreen extends ConsumerStatefulWidget {
  final PaymentMethod? edit;

  const PaymentMethodFormScreen({super.key, this.edit});

  @override
  ConsumerState<PaymentMethodFormScreen> createState() => _PaymentMethodFormScreenState();
}

class _PaymentMethodFormScreenState extends ConsumerState<PaymentMethodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _type = 'other';

  @override
  void initState() {
    super.initState();
    if (widget.edit != null) {
      _nameController.text = widget.edit!.name;
      _type = widget.edit!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.edit == null ? 'Nuevo medio' : 'Editar medio')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                DropdownMenuItem(value: 'debito', child: Text('Tarjeta débito')),
                DropdownMenuItem(value: 'other', child: Text('Otro')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'other'),
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
    final user = await ref.read(authStateProvider.future);
    if (user == null) return;
    final repo = ref.read(paymentMethodRepositoryProvider);
    final name = _nameController.text.trim();
    if (widget.edit != null) {
      await repo.update(widget.edit!.copyWith(name: name, type: _type));
    } else {
      final pm = PaymentMethod(
        id: const Uuid().v4(),
        userId: user.id,
        name: name,
        type: _type,
      );
      await repo.insert(pm);
      if (mounted) {
        ref.invalidate(paymentMethodsListProvider);
        ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
        Navigator.pop(context, pm.id);
        return;
      }
    }
    if (mounted) {
      ref.invalidate(paymentMethodsListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
      Navigator.pop(context);
    }
  }
}
