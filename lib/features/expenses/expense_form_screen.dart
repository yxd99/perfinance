import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
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
import 'package:perfinance/features/expenses/last_account.dart';
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

  /// Última cuenta usada (solo al crear). Se aplica una vez, cuando ya cargaron
  /// las cuentas, y nunca pisa una elección del usuario.
  LastAccount? _lastAccount;
  bool _lastAccountApplied = false;

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
      _loadLastAccount();
    }
  }

  Future<void> _loadLastAccount() async {
    try {
      final saved = await LastAccountStore.load();
      if (mounted && saved != null) setState(() => _lastAccount = saved);
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'expenses.load_last_account');
    }
  }

  /// Preselecciona la última cuenta si sigue disponible. Corre dentro de
  /// `build`, antes de dibujar los chips, así no hay un cuadro sin selección.
  void _applyLastAccount() {
    if (_isEdit || _lastAccountApplied || _lastAccount == null) return;
    final cards = ref.watch(activeCreditCardsListProvider);
    final methods = ref.watch(paymentMethodsListProvider);
    if (!cards.hasValue || !methods.hasValue) return;
    _lastAccountApplied = true;
    if (_selectedId != null) return;
    final resolved = resolveLastAccount(
      _lastAccount,
      activeCardIds: {for (final c in cards.value!) c.id},
      methodIds: {for (final m in methods.value!) m.id},
    );
    if (resolved == null) return;
    _isCreditCard = resolved.isCard;
    if (resolved.isCard) {
      _selectedCardId = resolved.paymentRef;
    } else {
      _selectedMethodId = resolved.paymentRef;
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
    _applyLastAccount();
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
      Row(
        children: [
          Expanded(child: Text('Monto', style: label)),
          _DateChip(label: expenseDayLabel(_date, now: DateTime.now()), onTap: _pickDate),
        ],
      ),
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
    ];
  }

  /// Rueda de fechas de iOS. Tope: hoy (o la fecha del egreso, si al editar
  /// quedó una futura de antes, para no romper el selector).
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final first = DateTime(2020);
    final max = _date.isAfter(endOfToday) ? _date : endOfToday;
    final min = _date.isBefore(first) ? _date : first;
    var picked = _date;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return Container(
          color: c.surface,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Listo', style: TextStyle(color: c.accent, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(
                  height: 216,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _date,
                    minimumDate: min,
                    maximumDate: max,
                    onDateTimeChanged: (d) => picked = d,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    // Tocar fuera también confirma (devuelve null), como la rueda en línea de iOS.
    if (!mounted || confirmed == false) return;
    setState(() => _date = picked);
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
        LastAccountStore.save(LastAccount(paymentType: paymentType, paymentRef: paymentRef)).catchError(
          (Object e, StackTrace st) =>
              ErrorReporter.capture(e, st, operation: 'expenses.save_last_account'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) {
      ref.invalidate(expensesListProvider);
      ref.invalidate(dashboardDebtProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
            (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'expenses.push'),
          );
      if (_isEdit) {
        Navigator.pop(context);
        return;
      }
      HapticFeedback.lightImpact();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Egreso registrado'), duration: Duration(seconds: 2)),
      );
    }
  }
}

/// Fecha compacta junto al monto: queda a la vista con el teclado abierto.
class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Fecha, $label',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.calendar, size: 18, color: c.accent),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: c.accent,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
