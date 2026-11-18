import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/data/repositories/payment_method_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/savings/payment_method_type.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/services/sync_service.dart';
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.edit != null) {
      _nameController.text = widget.edit!.name;
      _type = paymentMethodFormType(widget.edit!.type);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.edit == null ? 'Nuevo medio de pago' : 'Editar medio de pago')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Nombre', style: t.labelLarge?.copyWith(color: c.ink)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              autofocus: widget.edit == null,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Nequi, Efectivo, Débito Bancolombia'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Escribí un nombre' : null,
            ),
            const SizedBox(height: 20),
            Text('Tipo', style: t.labelLarge?.copyWith(color: c.ink)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _type,
                backgroundColor: c.track,
                thumbColor: c.surface,
                children: {
                  for (final e in paymentMethodFormTypes.entries)
                    e.key: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 36),
                      child: Center(
                        child: Text(
                          e.value,
                          style: TextStyle(
                            color: c.ink,
                            fontWeight: _type == e.key ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                },
                onValueChanged: (v) => setState(() => _type = v ?? 'other'),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _saving
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(c.accent)))
                  : Text(widget.edit == null ? 'Guardar medio de pago' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }

  /// Tipo a guardar. Si el usuario no lo cambió se conserva el valor original
  /// (las filas viejas con `cash`/`debit` no se reescriben solas).
  String _typeToSave() {
    final original = widget.edit?.type;
    if (original != null && paymentMethodFormType(original) == _type) return original;
    return _type;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) return;
      final repo = ref.read(paymentMethodRepositoryProvider);
      final name = _nameController.text.trim();
      String? createdId;
      if (widget.edit != null) {
        await repo.update(widget.edit!.copyWith(name: name, type: _typeToSave()));
      } else {
        final pm = PaymentMethod(
          id: const Uuid().v4(),
          userId: user.id,
          name: name,
          type: _type,
        );
        await repo.insert(pm);
        createdId = pm.id;
      }
      if (!mounted) return;
      ref.invalidate(paymentMethodsListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
            (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'savings.push'),
          );
      Navigator.pop(context, createdId);
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'savings.save', details: {'editing': widget.edit != null});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el medio de pago. Intentá de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
