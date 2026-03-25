import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:uuid/uuid.dart';

class AutomaticPaymentFormScreen extends ConsumerStatefulWidget {
  final AutomaticPayment? edit;

  const AutomaticPaymentFormScreen({super.key, this.edit});

  @override
  ConsumerState<AutomaticPaymentFormScreen> createState() => _AutomaticPaymentFormScreenState();
}

class _AutomaticPaymentFormScreenState extends ConsumerState<AutomaticPaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _nextRunDate = DateTime.now();
  bool _isCreditCard = true;
  String? _selectedCardId;
  String? _selectedMethodId;

  @override
  void initState() {
    super.initState();
    if (widget.edit != null) {
      final p = widget.edit!;
      _amountController.text = p.amount.toStringAsFixed(0);
      _descriptionController.text = p.description;
      _nextRunDate = p.nextRunDate;
      _isCreditCard = p.paymentType == 'credit_card';
      _selectedCardId = _isCreditCard ? p.paymentRef : null;
      _selectedMethodId = !_isCreditCard ? p.paymentRef : null;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(creditCardsListProvider).valueOrNull ?? [];
    final methods = ref.watch(paymentMethodsListProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit != null ? 'Editar pago automático' : 'Nuevo pago automático'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
                hintText: 'Ej: Netflix, gym, suscripción...',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa una descripción';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CurrencyTextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Próxima fecha de pago'),
              subtitle: Text(
                '${_nextRunDate.day}/${_nextRunDate.month}/${_nextRunDate.year} (se repetirá cada mes)',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextRunDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) setState(() => _nextRunDate = picked);
              },
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Tarjeta crédito'), icon: Icon(Icons.credit_card)),
                ButtonSegment(value: false, label: Text('Ahorro/efectivo'), icon: Icon(Icons.savings)),
              ],
              selected: {_isCreditCard},
              onSelectionChanged: (s) => setState(() {
                _isCreditCard = s.first;
                if (_isCreditCard) {
                  _selectedMethodId = null;
                } else {
                  _selectedCardId = null;
                }
              }),
            ),
            const SizedBox(height: 16),
            if (_isCreditCard) ...[
              DropdownButtonFormField<String>(
                value: _selectedCardId,
                decoration: const InputDecoration(
                  labelText: 'Tarjeta',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Selecciona tarjeta')),
                  ...cards.map((c) => DropdownMenuItem(value: c.id, child: Text(c.alias))),
                ],
                onChanged: (v) => setState(() => _selectedCardId = v),
                validator: (v) =>
                    _isCreditCard && (v == null || v.isEmpty) ? 'Selecciona una tarjeta' : null,
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                value: _selectedMethodId,
                decoration: const InputDecoration(
                  labelText: 'Medio de pago',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Selecciona medio')),
                  ...methods.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))),
                ],
                onChanged: (v) => setState(() => _selectedMethodId = v),
                validator: (v) =>
                    !_isCreditCard && (v == null || v.isEmpty) ? 'Selecciona un medio' : null,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(widget.edit != null ? 'Guardar cambios' : 'Crear pago automático'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = await ref.read(authStateProvider.future);
    if (user == null) return;
    final paymentType = _isCreditCard ? 'credit_card' : 'payment_method';
    final paymentRef = _isCreditCard ? _selectedCardId : _selectedMethodId;
    if (paymentRef == null || paymentRef.isEmpty) return;
    final amount = parseCurrency(_amountController.text);
    if (amount == null || amount <= 0) return;
    final description = _descriptionController.text.trim();

    final repo = ref.read(automaticPaymentRepositoryProvider);
    final nextRun = DateTime(_nextRunDate.year, _nextRunDate.month, _nextRunDate.day);

    if (widget.edit != null) {
      await repo.update(AutomaticPayment(
        id: widget.edit!.id,
        userId: user.id,
        paymentType: paymentType,
        paymentRef: paymentRef,
        amount: amount,
        description: description,
        nextRunDate: nextRun,
        syncStatus: widget.edit!.syncStatus,
        updatedAt: widget.edit!.updatedAt,
        createdAt: widget.edit!.createdAt,
      ));
    } else {
      await repo.insert(AutomaticPayment(
        id: const Uuid().v4(),
        userId: user.id,
        paymentType: paymentType,
        paymentRef: paymentRef,
        amount: amount,
        description: description,
        nextRunDate: nextRun,
      ));
    }
    if (mounted) {
      ref.invalidate(automaticPaymentsListProvider);
      ref.invalidate(expensesListProvider);
      Navigator.pop(context);
    }
  }
}
