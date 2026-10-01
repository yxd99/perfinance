import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/services/process_automatic_payments_service.dart';
import 'package:uuid/uuid.dart';

const _frequencies = <String>['mensual', 'trimestral', 'semestral', 'anual'];
const _frequencyLabels = <String, String>{
  'mensual': 'Mensual',
  'trimestral': 'Trimestral',
  'semestral': 'Semestral',
  'anual': 'Anual',
};

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
  final _dayController = TextEditingController();
  String _frequency = 'mensual';
  bool _isCreditCard = true;
  String? _selectedCardId;
  String? _selectedMethodId;
  DateTime? _nextRunDateOverride;

  void _onDayChanged() => setState(() {});

  DateTime? get _computedNextDate {
    final day = int.tryParse(_dayController.text.trim());
    if (day == null || day < 1 || day > 31) return null;
    return nextRunDateFor(
      frequency: _frequency,
      dayOfMonth: day,
      from: DateTime.now(),
    );
  }

  DateTime? get _nextDate => _nextRunDateOverride ?? _computedNextDate;

  Future<void> _pickNextRunDate() async {
    final initial = _nextDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _nextRunDateOverride = picked);
  }

  @override
  void initState() {
    super.initState();
    if (widget.edit != null) {
      final p = widget.edit!;
      _amountController.text = formatCurrency(p.amount.round());
      _descriptionController.text = p.description;
      _isCreditCard = p.paymentType == 'credit_card';
      _selectedCardId = _isCreditCard ? p.paymentRef : null;
      _selectedMethodId = !_isCreditCard ? p.paymentRef : null;
      // Precargar día y frecuencia; fallback legacy desde nextRunDate
      _dayController.text = p.paymentDayOfMonth.toString();
      _frequency = p.frequency;
      _nextRunDateOverride = p.nextRunDate;
    }
    _dayController.addListener(_onDayChanged);
  }

  @override
  void dispose() {
    _dayController.removeListener(_onDayChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(activeCreditCardsListProvider).valueOrNull ?? [];
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
            if (_nextDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: _pickNextRunDate,
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Próximo pago: ${formatDisplayDate(_nextDate!)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Icon(Icons.edit, color: Colors.green, size: 18),
                      if (_nextRunDateOverride != null)
                        TextButton(
                          onPressed: () => setState(() => _nextRunDateOverride = null),
                          child: const Text('Restablecer'),
                        ),
                    ],
                  ),
                ),
              ),
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
            TextFormField(
              controller: _dayController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Día del mes (1–31)',
                border: OutlineInputBorder(),
                hintText: 'Ej: 15',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa un día entre 1 y 31';
                final day = int.tryParse(v.trim());
                if (day == null || day < 1 || day > 31) return 'Ingresa un día entre 1 y 31';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frecuencia',
                border: OutlineInputBorder(),
              ),
              items: _frequencies
                  .map(
                    (f) => DropdownMenuItem(
                      value: f,
                      child: Text(_frequencyLabels[f]!),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _frequency = v);
              },
              validator: (v) => (v == null || v.isEmpty) ? 'Selecciona una frecuencia' : null,
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
                // Guard: solo preseleccionar si el item está en la lista cargada
                value: cards.any((c) => c.id == _selectedCardId) ? _selectedCardId : null,
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
                // Guard: solo preseleccionar si el item está en la lista cargada
                value: methods.any((m) => m.id == _selectedMethodId) ? _selectedMethodId : null,
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
    final dayOfMonth = int.parse(_dayController.text.trim());

    // Al editar sin tocar la fecha: conservar el nextRunDate existente para que el
    // proceso automático lo ejecute y avance la fecha. Llamar a nextRunDateFor aquí
    // saltaría un período sin crear el egreso correspondiente. Si el usuario ajustó
    // la fecha manualmente (_nextRunDateOverride), esa tiene prioridad siempre.
    final nextRun = _nextRunDateOverride ??
        (widget.edit != null
            ? widget.edit!.nextRunDate
            : nextRunDateFor(
                frequency: _frequency,
                dayOfMonth: dayOfMonth,
                from: DateTime.now(),
              ));

    final repo = ref.read(automaticPaymentRepositoryProvider);

    if (widget.edit != null) {
      await repo.update(AutomaticPayment(
        id: widget.edit!.id,
        userId: user.id,
        paymentType: paymentType,
        paymentRef: paymentRef,
        amount: amount,
        description: description,
        nextRunDate: nextRun,
        paymentDayOfMonth: dayOfMonth,
        frequency: _frequency,
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
        paymentDayOfMonth: dayOfMonth,
        frequency: _frequency,
      ));
    }
    if (mounted) {
      ref.invalidate(automaticPaymentsListProvider);
      ref.invalidate(expensesListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
      Navigator.pop(context);
    }
  }
}
