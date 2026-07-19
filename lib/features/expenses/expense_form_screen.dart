import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/credit_cards/credit_card_form_screen.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/features/savings/payment_method_form_screen.dart';
import 'package:uuid/uuid.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.edit});

  final Expense? edit;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isCreditCard = true;
  String? _selectedCardId;
  String? _selectedMethodId;

  @override
  void initState() {
    super.initState();
    if (widget.edit != null) {
      final e = widget.edit!;
      _amountController.text = formatCurrency(e.amount.round());
      _descriptionController.text = e.description ?? '';
      _date = e.date.toLocal();
      _isCreditCard = e.paymentType == 'credit_card';
      _selectedCardId = _isCreditCard ? e.paymentRef : null;
      _selectedMethodId = !_isCreditCard ? e.paymentRef : null;
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
    final cards = ref.watch(activeCreditCardsListProvider).valueOrNull ?? [];
    final methods = ref.watch(paymentMethodsListProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.edit != null ? 'Editar egreso' : 'Nuevo egreso')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CurrencyTextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción (en qué fue el gasto)',
                border: OutlineInputBorder(),
                hintText: 'Ej: Supermercado, transporte...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Fecha'),
              subtitle: Text(formatDisplayDate(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Tarjeta crédito'), icon: Icon(Icons.credit_card)),
                ButtonSegment(value: false, label: Text('Ahorro/efectivo'), icon: Icon(Icons.savings)),
              ],
              selected: {_isCreditCard},
              onSelectionChanged: (s) => setState(() => _isCreditCard = s.first),
            ),
            const SizedBox(height: 16),
            if (_isCreditCard) ...[
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedCardId),
                initialValue: _selectedCardId,
                decoration: const InputDecoration(labelText: 'Tarjeta', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Selecciona tarjeta')),
                  ...cards.map((c) => DropdownMenuItem(value: c.id, child: Text(c.alias))),
                ],
                onChanged: (v) => setState(() => _selectedCardId = v),
                validator: (v) => _isCreditCard && (v == null || v.isEmpty) ? 'Selecciona una tarjeta' : null,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final id = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const CreditCardFormScreen()),
                  );
                  if (id != null && mounted) {
                    ref.invalidate(creditCardsListProvider);
                    ref.invalidate(activeCreditCardsListProvider);
                    setState(() => _selectedCardId = id);
                  }
                },
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('Registrar nueva tarjeta'),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedMethodId),
                initialValue: _selectedMethodId,
                decoration: const InputDecoration(labelText: 'Medio de pago', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Selecciona medio')),
                  ...methods.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))),
                ],
                onChanged: (v) => setState(() => _selectedMethodId = v),
                validator: (v) => !_isCreditCard && (v == null || v.isEmpty) ? 'Selecciona un medio' : null,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final id = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const PaymentMethodFormScreen()),
                  );
                  if (id != null && mounted) {
                    ref.invalidate(paymentMethodsListProvider);
                    setState(() => _selectedMethodId = id);
                  }
                },
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('Registrar nuevo medio de pago'),
              ),
            ],
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
    final paymentType = _isCreditCard ? 'credit_card' : 'payment_method';
    final paymentRef = _isCreditCard ? _selectedCardId : _selectedMethodId;
    if (paymentRef == null || paymentRef.isEmpty) return;
    final amount = parseCurrency(_amountController.text);
    if (amount == null || amount <= 0) return;
    final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
    final repo = ref.read(expenseRepositoryProvider);
    if (widget.edit != null) {
      await repo.update(widget.edit!.copyWith(
        amount: amount,
        date: _date,
        paymentType: paymentType,
        paymentRef: paymentRef,
        description: description,
      ));
    } else {
      await repo.insert(Expense(
        id: const Uuid().v4(),
        userId: user.id,
        amount: amount,
        date: _date,
        paymentType: paymentType,
        paymentRef: paymentRef,
        description: description,
      ));
    }
    if (mounted) {
      ref.invalidate(expensesListProvider);
      ref.invalidate(dashboardDebtProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
      Navigator.pop(context);
    }
  }
}
