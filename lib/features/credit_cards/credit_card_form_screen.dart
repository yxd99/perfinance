import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:uuid/uuid.dart';

class CreditCardFormScreen extends ConsumerStatefulWidget {
  final CreditCard? editCard;

  const CreditCardFormScreen({super.key, this.editCard});

  @override
  ConsumerState<CreditCardFormScreen> createState() => _CreditCardFormScreenState();
}

class _CreditCardFormScreenState extends ConsumerState<CreditCardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  final _cutOffController = TextEditingController();
  final _feeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.editCard != null) {
      _aliasController.text = widget.editCard!.alias;
      _cutOffController.text = widget.editCard!.cutOffDay.toString();
      _feeController.text = formatCurrency(widget.editCard!.managementFee);
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _cutOffController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editCard == null ? 'Nueva tarjeta' : 'Editar tarjeta')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _aliasController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Alias', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un alias' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cutOffController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Día de corte (1-31)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa el día de corte';
                final n = int.tryParse(v);
                if (n == null || n < 1 || n > 31) return 'Entre 1 y 31';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CurrencyTextField(
              controller: _feeController,
              decoration: const InputDecoration(
                labelText: 'Cuota de manejo',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa la cuota';
                final val = parseCurrency(v);
                if (val == null || val < 0) return 'Monto inválido';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Guardar'),
            ),
            if (widget.editCard != null) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar tarjeta'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final card = widget.editCard;
    if (card == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarjeta'),
        content: Text('¿Eliminar "${card.alias}"? Los pagos de esta tarjeta se quitarán al sincronizar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(creditCardRepositoryProvider).delete(card.id);
    if (!mounted) return;
    ref.invalidate(creditCardsListProvider);
    ref.invalidate(dashboardDebtProvider);
    ref.invalidate(expensesListProvider);
    ref.invalidate(automaticPaymentsListProvider);
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = await ref.read(authStateProvider.future);
    if (user == null) return;
    final repo = ref.read(creditCardRepositoryProvider);
    final alias = _aliasController.text.trim();
    final cutOff = int.parse(_cutOffController.text);
    final fee = parseCurrency(_feeController.text);
    if (fee == null || fee < 0) return;

    if (widget.editCard != null) {
      final updated = widget.editCard!.copyWith(alias: alias, cutOffDay: cutOff, managementFee: fee);
      await repo.update(updated);
    } else {
      final card = CreditCard(
        id: const Uuid().v4(),
        userId: user.id,
        alias: alias,
        cutOffDay: cutOff,
        managementFee: fee,
      );
      await repo.insert(card);
      if (mounted) {
        ref.invalidate(creditCardsListProvider);
        Navigator.of(context).pop(card.id);
        return;
      }
    }
    if (mounted) {
      ref.invalidate(creditCardsListProvider);
      Navigator.of(context).pop();
    }
  }
}
