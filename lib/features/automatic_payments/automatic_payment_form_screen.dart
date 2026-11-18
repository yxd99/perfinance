import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payment_copy.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/services/process_automatic_payments_service.dart';
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
    return nextRunDateFor(frequency: _frequency, dayOfMonth: day, from: DateTime.now());
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
      appBar: AppBar(title: Text(widget.edit != null ? 'Editar pago automático' : 'Nuevo pago automático')),
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
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.calendar, color: context.colors.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Próximo pago: ${formatDisplayDate(_nextDate!)}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(color: context.colors.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Semantics(
                          label: 'Cambiar fecha',
                          child: Icon(CupertinoIcons.pencil, color: context.colors.accent, size: 18),
                        ),
                        if (_nextRunDateOverride != null)
                          TextButton(
                            onPressed: () => setState(() => _nextRunDateOverride = null),
                            child: const Text('Restablecer'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descripción', hintText: 'Ej: Netflix, gym, suscripción...'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresá una descripción';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CurrencyTextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Monto'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dayController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Día del mes (1–31)', hintText: 'Ej: 15'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresá un día entre 1 y 31';
                final day = int.tryParse(v.trim());
                if (day == null || day < 1 || day > 31) return 'Ingresá un día entre 1 y 31';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frecuencia'),
              items: automaticPaymentFrequencies
                  .map((f) => DropdownMenuItem(value: f, child: Text(frequencyLabel(f))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _frequency = v);
              },
              validator: (v) => (v == null || v.isEmpty) ? 'Elegí una frecuencia' : null,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            CupertinoSlidingSegmentedControl<bool>(
              groupValue: _isCreditCard,
              backgroundColor: context.colors.track,
              thumbColor: context.colors.surface,
              children: {
                for (final e in const {true: 'Tarjeta de crédito', false: 'Ahorro o efectivo'}.entries)
                  e.key: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: context.colors.ink,
                        fontWeight: _isCreditCard == e.key ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
              },
              onValueChanged: (v) => setState(() {
                if (v == null) return;
                _isCreditCard = v;
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
                initialValue: cards.any((c) => c.id == _selectedCardId) ? _selectedCardId : null,
                decoration: const InputDecoration(labelText: 'Tarjeta'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Elegí una tarjeta')),
                  ...cards.map((c) => DropdownMenuItem(value: c.id, child: Text(c.alias))),
                ],
                onChanged: (v) => setState(() => _selectedCardId = v),
                validator: (v) => _isCreditCard && (v == null || v.isEmpty) ? 'Elegí una tarjeta' : null,
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                // Guard: solo preseleccionar si el item está en la lista cargada
                initialValue: methods.any((m) => m.id == _selectedMethodId) ? _selectedMethodId : null,
                decoration: const InputDecoration(labelText: 'Medio de pago'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Elegí un medio de pago')),
                  ...methods.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))),
                ],
                onChanged: (v) => setState(() => _selectedMethodId = v),
                validator: (v) => !_isCreditCard && (v == null || v.isEmpty) ? 'Elegí un medio de pago' : null,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
    if (user == null || !mounted) return;
    final paymentType = _isCreditCard ? 'credit_card' : 'payment_method';
    final paymentRef = _isCreditCard ? _selectedCardId : _selectedMethodId;
    if (paymentRef == null || paymentRef.isEmpty) return;
    final amount = parseCurrency(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El monto debe ser mayor a cero.')));
      return;
    }
    final description = _descriptionController.text.trim();
    final dayOfMonth = int.parse(_dayController.text.trim());

    // Al editar sin tocar la fecha: conservar el nextRunDate existente para que el
    // proceso automático lo ejecute y avance la fecha. Llamar a nextRunDateFor aquí
    // saltaría un período sin crear el egreso correspondiente. Si el usuario ajustó
    // la fecha manualmente (_nextRunDateOverride), esa tiene prioridad siempre.
    final nextRun =
        _nextRunDateOverride ??
        (widget.edit != null
            ? widget.edit!.nextRunDate
            : nextRunDateFor(frequency: _frequency, dayOfMonth: dayOfMonth, from: DateTime.now()));

    final repo = ref.read(automaticPaymentRepositoryProvider);

    try {
      if (widget.edit != null) {
        await repo.update(
          AutomaticPayment(
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
          ),
        );
      } else {
        await repo.insert(
          AutomaticPayment(
            id: const Uuid().v4(),
            userId: user.id,
            paymentType: paymentType,
            paymentRef: paymentRef,
            amount: amount,
            description: description,
            nextRunDate: nextRun,
            paymentDayOfMonth: dayOfMonth,
            frequency: _frequency,
          ),
        );
      }
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'automatic_payments.save', details: {'editing': widget.edit != null});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar el pago automático. Probá de nuevo.',
              style: TextStyle(color: context.colors.onDanger),
            ),
            backgroundColor: context.colors.danger,
          ),
        );
      }
      return;
    }
    if (mounted) {
      ref.invalidate(automaticPaymentsListProvider);
      ref.invalidate(expensesListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
      Navigator.pop(context);
    }
  }
}
