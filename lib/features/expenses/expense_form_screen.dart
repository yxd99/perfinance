import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/credit_cards/credit_card_form_screen.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/expenses/expense_list_formatting.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/widgets/account_note_chip.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/features/savings/payment_method_form_screen.dart';
import 'package:uuid/uuid.dart';

/// Formulario de egreso: monto primero, cuenta, descripción y fecha (hoy por
/// defecto). Como pantalla completa sirve para editar y para el deep link;
/// con [asSheet] se dibuja como contenido de una hoja (registro rápido).
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({
    super.key,
    this.edit,
    this.initialAmount,
    this.initialDescription,
    this.asSheet = false,
  });

  final Expense? edit;

  /// Prefill values for a new expense (e.g. from a deep link triggered by
  /// an Apple Pay Shortcuts automation). Ignored when [edit] is set.
  final double? initialAmount;
  final String? initialDescription;

  /// Sin `Scaffold` ni `AppBar`: el contenido de una hoja modal.
  final bool asSheet;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _AccountOption {
  const _AccountOption(this.id, this.label, {required this.isCard});
  final String id;
  final String label;
  final bool isCard;
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isCreditCard = true;
  String? _selectedCardId;
  String? _selectedMethodId;
  bool _saving = false;

  bool get _isEdit => widget.edit != null;
  String? get _selectedId => _isCreditCard ? _selectedCardId : _selectedMethodId;

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
    } else {
      if (widget.initialAmount != null) {
        _amountController.text = formatCurrency(widget.initialAmount!.round());
      }
      if (widget.initialDescription != null) {
        _descriptionController.text = widget.initialDescription!;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _select(_AccountOption o) {
    setState(() {
      _isCreditCard = o.isCard;
      if (o.isCard) {
        _selectedCardId = o.id;
      } else {
        _selectedMethodId = o.id;
      }
    });
  }

  List<_AccountOption> _accountOptions() {
    final cards = ref.watch(activeCreditCardsListProvider).valueOrNull ?? [];
    final methods = ref.watch(paymentMethodsListProvider).valueOrNull ?? [];
    final options = [
      for (final c in cards) _AccountOption(c.id, c.alias, isCard: true),
      for (final m in methods) _AccountOption(m.id, m.name, isCard: false),
    ];
    // Al editar un egreso de una tarjeta desactivada, la cuenta igual se muestra.
    final selected = _selectedId;
    if (selected != null && options.every((o) => o.id != selected)) {
      final display = ref.watch(expensePaymentDisplayProvider).valueOrNull;
      final label = _isCreditCard ? display?.cardAliases[selected] : display?.methodNames[selected];
      options.insert(0, _AccountOption(selected, label ?? 'Cuenta actual', isCard: _isCreditCard));
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Editar egreso' : 'Registrá un egreso';
    final fields = _buildFields(context);
    final save = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_isEdit ? 'Guardar cambios' : 'Guardar egreso'),
        ),
      ),
    );

    if (widget.asSheet) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: fields,
                  ),
                ),
              ),
              save,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: fields,
              ),
            ),
            save,
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final options = _accountOptions();
    final label = t.labelLarge?.copyWith(color: c.textMuted);

    return [
      Text('Monto', style: label),
      TextFormField(
        controller: _amountController,
        autofocus: !_isEdit,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
        style: t.displaySmall?.copyWith(color: c.ink, fontFeatures: kTabularFigures),
        decoration: InputDecoration(
          prefixText: '\$ ',
          prefixStyle: t.displaySmall?.copyWith(color: c.textMuted),
          hintText: '0',
          hintStyle: t.displaySmall?.copyWith(color: c.textMuted, fontWeight: FontWeight.w300),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Ingresá el monto';
          final val = parseCurrency(v);
          if (val == null || val <= 0) return 'Monto inválido';
          return null;
        },
      ),
      const SizedBox(height: 16),
      Text('Cuenta', style: label),
      const SizedBox(height: 8),
      FormField<String>(
        validator: (_) => (_selectedId == null || _selectedId!.isEmpty) ? 'Elegí una tarjeta o cuenta' : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final o in options)
                  ChoiceChip(
                    avatar: AccountNoteChip(color: ref.accountHue(context, o.id)),
                    label: Text(o.label),
                    showCheckmark: false,
                    selected: o.isCard == _isCreditCard && o.id == _selectedId,
                    selectedColor: c.accentSoft,
                    side: BorderSide(
                      color: o.isCard == _isCreditCard && o.id == _selectedId ? c.accent : c.divider,
                      width: o.isCard == _isCreditCard && o.id == _selectedId ? 1.5 : 1,
                    ),
                    onSelected: (_) {
                      _select(o);
                      state.didChange(o.id);
                    },
                  ),
                ActionChip(
                  avatar: Icon(CupertinoIcons.add, size: 18, color: c.accent),
                  label: const Text('Nueva cuenta'),
                  labelStyle: TextStyle(color: c.accent),
                  backgroundColor: Colors.transparent,
                  onPressed: () => _addAccount(state),
                ),
              ],
            ),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Agregá una tarjeta o cuenta para registrar el egreso.',
                  style: t.bodySmall?.copyWith(color: c.textMuted),
                ),
              ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(state.errorText!, style: t.bodySmall?.copyWith(color: c.danger)),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _descriptionController,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Descripción',
          hintText: '¿En qué fue? Ej: mercado, taxi',
        ),
      ),
      const SizedBox(height: 8),
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pickDate,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(CupertinoIcons.calendar, size: 20, color: c.textMuted),
                const SizedBox(width: 12),
                Expanded(child: Text('Fecha', style: t.bodyLarge)),
                Text(
                  expenseDayLabel(_date, now: DateTime.now()),
                  style: t.bodyLarge?.copyWith(color: c.accent, fontWeight: FontWeight.w600),
                ),
                Icon(CupertinoIcons.chevron_right, size: 18, color: c.textMuted),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addAccount(FormFieldState<String> field) async {
    final isCard = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.creditcard),
              title: const Text('Tarjeta de crédito'),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.money_dollar_circle),
              title: const Text('Ahorro, débito o efectivo'),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (isCard == null || !mounted) return;
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => isCard ? const CreditCardFormScreen() : const PaymentMethodFormScreen(),
      ),
    );
    if (id == null || !mounted) return;
    if (isCard) {
      ref.invalidate(creditCardsListProvider);
      ref.invalidate(activeCreditCardsListProvider);
    } else {
      ref.invalidate(paymentMethodsListProvider);
    }
    _select(_AccountOption(id, '', isCard: isCard));
    field.didChange(id);
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
    setState(() => _saving = true);
    try {
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) {
      ref.invalidate(expensesListProvider);
      ref.invalidate(dashboardDebtProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
      Navigator.pop(context);
    }
  }
}
