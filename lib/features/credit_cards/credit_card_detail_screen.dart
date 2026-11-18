import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/core/utils/date_utils.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/card_payment.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/models/min_payment_config.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/data/repositories/min_payment_config_repository.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/card_payment_date_filter.dart';
import 'package:perfinance/features/credit_cards/card_debt_validation_dialog.dart';
import 'package:perfinance/features/credit_cards/credit_card_form_screen.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/credit_cards/credit_card_payments_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/credit_cards/widgets/card_inset_group.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/services/card_debt_reconciliation_service.dart';
import 'package:perfinance/services/credit_card_lifecycle_service.dart';
import 'package:perfinance/services/min_payment_service.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:uuid/uuid.dart';

class CreditCardDetailScreen extends ConsumerStatefulWidget {
  final String cardId;

  const CreditCardDetailScreen({super.key, required this.cardId});

  @override
  ConsumerState<CreditCardDetailScreen> createState() => _CreditCardDetailScreenState();
}

class _CreditCardDetailScreenState extends ConsumerState<CreditCardDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final asyncCards = ref.watch(creditCardsListProvider);
    return asyncCards.when(
      data: (cards) {
        final card = cards.cast<CreditCard?>().firstWhere(
              (c) => c?.id == widget.cardId,
              orElse: () => null,
            );
        if (card == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('No encontramos esta tarjeta. Puede que se haya eliminado.')),
          );
        }
        return _DetailContent(card: card);
      },
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator.adaptive())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle, size: 44, color: context.colors.danger),
                const SizedBox(height: 16),
                Text(
                  UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.cardsLoadFailed),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailContent extends ConsumerStatefulWidget {
  final CreditCard card;

  const _DetailContent({required this.card});

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  late Future<MinPaymentStatus?> _minStatusFuture;

  @override
  void initState() {
    super.initState();
    _minStatusFuture = _fetchMinStatus();
  }

  Future<MinPaymentStatus?> _fetchMinStatus() async {
    final repo = ref.read(minPaymentConfigRepositoryProvider);
    final payRepo = ref.read(cardPaymentRepositoryProvider);
    return MinPaymentService.getStatus(repo, payRepo, widget.card.id);
  }

  void _refreshMinStatus() {
    setState(() {
      _minStatusFuture = _fetchMinStatus();
    });
  }

  Future<double> _getCurrentDebt() async {
    final user = await ref.read(authStateProvider.future);
    if (user == null) return 0;
    final expenseRepo = ref.read(expenseRepositoryProvider);
    final paymentRepo = ref.read(cardPaymentRepositoryProvider);
    final expenses = await expenseRepo.getAll(user.id);
    final payments = await paymentRepo.getByCardId(widget.card.id);
    return CardDebtReconciliationService.currentDebtForCard(
      cardId: widget.card.id,
      expenses: expenses,
      payments: payments,
    );
  }

  /// Avisa abajo que algo no se pudo guardar. El error ya se reportó.
  void _showSaveError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleActive(BuildContext context, bool newValue) async {
    final isDeactivating = !newValue;
    if (isDeactivating) {
      final debt = await _getCurrentDebt();
      if (!context.mounted) return;
      if (debt > 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Desactivar tarjeta'),
            content: Text(
              'Esta tarjeta tiene una deuda de \$${formatCurrency(debt)}. '
              'Puedes seguir viéndola y pagándola, pero no podrás usarla para nuevos egresos. ¿Confirmas?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }
    final cardRepo = ref.read(creditCardRepositoryProvider);
    final autoPayRepo = ref.read(automaticPaymentRepositoryProvider);
    try {
      await CreditCardLifecycleService.setActive(cardRepo, autoPayRepo, widget.card.id, newValue);
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'credit_cards.set_active', details: {'card_id': widget.card.id, 'active': newValue});
      _showSaveError(newValue ? 'No pudimos reactivar la tarjeta. Prueba de nuevo.' : 'No pudimos desactivar la tarjeta. Prueba de nuevo.');
      return;
    }
    if (!mounted) return;
    ref.invalidate(creditCardsListProvider);
    ref.invalidate(activeCreditCardsListProvider);
    ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
          (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'credit_cards.push'),
        );
    if (newValue) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Tarjeta reactivada')),
      );
    }
  }

  /// Abre el formulario de la tarjeta. Si se eliminó desde ahí, este detalle
  /// ya no tiene qué mostrar y se cierra también.
  Future<void> _editCard() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => CreditCardFormScreen(editCard: widget.card)),
    );
    if (result == CreditCardFormScreen.deletedResult && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    final asyncPayments = ref.watch(filteredCardPaymentsByCardProvider(widget.card.id));
    final selectedPaymentFilter = ref.watch(selectedCardPaymentDateFilterProvider(widget.card.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card.alias),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(CupertinoIcons.pencil),
            onPressed: _editCard,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          _CardSummary(
            card: widget.card,
            hue: ref.accountHue(context, widget.card.id),
            hideValues: hideValues,
            debtFuture: _getCurrentDebt(),
          ),
          FutureBuilder<MinPaymentStatus?>(
            future: _minStatusFuture,
            builder: (context, snap) {
              final status = snap.data;
              final isLoading = snap.connectionState == ConnectionState.waiting;
              return CardInsetGroup(
                header: 'Pago mínimo',
                children: [
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    )
                  else if (status != null) ...[
                    CardInfoRow(
                      label: 'Pagado este mes',
                      value: '\$${formatCurrencyDisplay(status.totalPaidMonth, hideValues)}',
                    ),
                    CardInfoRow(
                      label: 'Abonado al mínimo',
                      value:
                          '\$${formatCurrencyDisplay(status.paid, hideValues)} de \$${formatCurrencyDisplay(status.configured, hideValues)}',
                    ),
                    if (status.isUpToDate)
                      CardInfoRow(label: 'Estado', value: 'Estás al día', valueColor: c.positive)
                    else
                      CardInfoRow(
                        label: 'Te falta',
                        value: '\$${formatCurrencyDisplay(status.pending, hideValues)}',
                        valueColor: c.warning,
                      ),
                  ] else
                    const CardInfoRow(label: 'Pago mínimo', value: 'Sin configurar'),
                  CardActionRow(
                    icon: CupertinoIcons.plus_circle,
                    label: 'Registrar pago',
                    onTap: () => _registerPayment(context),
                  ),
                  CardActionRow(
                    icon: CupertinoIcons.slider_horizontal_3,
                    label: status == null ? 'Configurar pago mínimo' : 'Editar pago mínimo',
                    onTap: () => _setMinPayment(context),
                  ),
                  CardActionRow(
                    icon: CupertinoIcons.checkmark_seal,
                    label: 'Validar deuda actual',
                    onTap: () => _validateCurrentDebt(context),
                  ),
                ],
              );
            },
          ),
          CardInsetGroup(
            children: [
              SwitchListTile.adaptive(
                title: const Text('Tarjeta activa'),
                subtitle: Text(
                  widget.card.isActive
                      ? 'Aparece al registrar egresos.'
                      : 'Desactivada: no aparece al registrar egresos, pero puedes seguir pagándola.',
                ),
                activeTrackColor: c.accent,
                value: widget.card.isActive,
                onChanged: (v) => _toggleActive(context, v),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
            child: Semantics(
              header: true,
              child: Text(
                'HISTORIAL DE PAGOS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: c.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
              ),
            ),
          ),
          _PaymentFilterBar(
            selected: selectedPaymentFilter,
            onSelected: (f) => ref.read(selectedCardPaymentDateFilterProvider(widget.card.id).notifier).state = f,
            onPickCustomRange: () => _pickCustomPaymentRange(context),
          ),
          const SizedBox(height: 8),
          asyncPayments.when(
            data: (payments) {
              final total = payments.fold<double>(0, (s, p) => s + p.amount);
              return CardInsetGroup(
                children: [
                  CardInfoRow(label: 'Total del rango', value: '\$${formatCurrencyDisplay(total, hideValues)}'),
                  if (payments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No hay pagos en este rango.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.textMuted),
                      ),
                    )
                  else
                    for (final p in payments)
                      _PaymentRow(
                        amount: '\$${formatCurrencyDisplay(p.amount, hideValues)}',
                        date: formatDisplayDate(p.date.toLocal()),
                        onEdit: () => _editPayment(context, p),
                        onDelete: () => _deletePayment(context, p),
                      ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Text(
                UserFriendlyErrors.fromAsyncError(e, 'No pudimos cargar el historial de pagos.'),
                style: TextStyle(color: c.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomPaymentRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (range != null) {
      ref.read(selectedCardPaymentDateFilterProvider(widget.card.id).notifier).state = CardPaymentDateFilter.custom(range);
    }
  }

  Future<void> _setMinPayment(BuildContext context) async {
    final now = DateTime.now();
    final repo = ref.read(minPaymentConfigRepositoryProvider);
    final existing = await repo.getForCardAndMonth(widget.card.id, now.year, now.month);
    if (!context.mounted) return;

    final isCreateMode = existing == null;
    final c = TextEditingController();
    if (existing != null) {
      c.text = formatCurrency(existing.amount);
    }

    // effectiveDay picker state — defaults to today's day in create mode
    int selectedDay = existing?.effectiveDay ?? now.day.clamp(1, lastDayOfMonth(now.year, now.month));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final showWarning = isCreateMode && selectedDay > 25;
          return AlertDialog(
            title: Text(isCreateMode ? 'Pago mínimo' : 'Editar pago mínimo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CurrencyTextField(
                    controller: c,
                    decoration: const InputDecoration(labelText: 'Monto'),
                  ),
                  const SizedBox(height: 12),
                  // Task 5.1: effectiveDay field — editable in create, disabled in edit
                  Text(
                    'Día de referencia del mes',
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedDay,
                          decoration: InputDecoration(enabled: isCreateMode),
                          onChanged: isCreateMode
                              ? (v) {
                                  if (v != null) {
                                    setDialogState(() => selectedDay = v);
                                  }
                                }
                              : null,
                          items: List.generate(
                            lastDayOfMonth(now.year, now.month),
                            (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Task 5.1: edit mode caption
                  if (!isCreateMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Solo puedes modificar el monto este mes. La fecha de referencia queda fija en el día ${existing.effectiveDay}.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: ctx.colors.textMuted),
                      ),
                    ),
                  // Task 5.2: late-date warning
                  if (showWarning)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Configuraste una fecha de referencia tardía — la mayoría de tus pagos de este mes no contarán hacia el mínimo.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: ctx.colors.warning,
                        ),
                      ),
                    ),
                  // Task 5.3: disclaimer
                  const SizedBox(height: 12),
                  Text(
                    'Esta fecha solo afecta cómo la app registra tus pagos. Tu banco cuenta todos los pagos del ciclo.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: ctx.colors.textMuted),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (c.text.trim().isNotEmpty) Navigator.pop(ctx, true);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    final amount = parseCurrency(c.text);
    if (amount == null || amount < 0) return;

    try {
      if (existing != null) {
        // Edit mode: update amount only
        await repo.update(MinPaymentConfig(
          id: existing.id,
          cardId: widget.card.id,
          amount: amount,
          year: now.year,
          month: now.month,
          effectiveDay: existing.effectiveDay,
        ));
      } else {
        // Create mode: insert with effectiveDay
        await repo.insert(MinPaymentConfig(
          id: const Uuid().v4(),
          cardId: widget.card.id,
          amount: amount,
          year: now.year,
          month: now.month,
          effectiveDay: selectedDay,
        ));
      }
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'credit_cards.save_min_payment', details: {'card_id': widget.card.id});
      _showSaveError('No pudimos guardar el pago mínimo. Prueba de nuevo.');
      return;
    }

    if (mounted) {
      _refreshMinStatus();
      ref.invalidate(dashboardMinPaymentSummaryProvider);
    }
  }

  Future<void> _registerPayment(BuildContext context) async {
    final amountC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar pago'),
        content: CurrencyTextField(
          controller: amountC,
          decoration: const InputDecoration(labelText: 'Monto'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (amountC.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || amountC.text.trim().isEmpty) return;
    final amount = parseCurrency(amountC.text);
    if (amount == null || amount <= 0) return;
    final payRepo = ref.read(cardPaymentRepositoryProvider);
    try {
      await payRepo.insert(CardPayment(
        id: const Uuid().v4(),
        cardId: widget.card.id,
        amount: amount,
        date: DateTime.now(),
      ));
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'credit_cards.register_payment', details: {'card_id': widget.card.id});
      _showSaveError('No pudimos registrar el pago. Prueba de nuevo.');
      return;
    }
    if (mounted) {
      _refreshMinStatus();
      ref.invalidate(dashboardDebtProvider);
      ref.invalidate(dashboardMinPaymentSummaryProvider);
      ref.invalidate(cardPaymentsByCardProvider(widget.card.id));
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
            (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'credit_cards.push'),
          );
    }
  }

  Future<void> _validateCurrentDebt(BuildContext context) async {
    final user = await ref.read(authStateProvider.future);
    if (user == null || !mounted) return;

    final expenseRepo = ref.read(expenseRepositoryProvider);
    final paymentRepo = ref.read(cardPaymentRepositoryProvider);
    final expenses = await expenseRepo.getAll(user.id);
    final payments = await paymentRepo.getByCardId(widget.card.id);
    final expectedDebt = CardDebtReconciliationService.currentDebtForCard(
      cardId: widget.card.id,
      expenses: expenses,
      payments: payments,
    );
    if (!context.mounted) return;

    final decision = await showCardDebtValidationDialog(
      context: context,
      expectedDebt: expectedDebt,
      title: 'Validar deuda de ${widget.card.alias}',
    );
    if (decision == null) return;

    try {
      if (decision.reconciliation.action == CardDebtAdjustmentAction.missingExpense) {
        await expenseRepo.insert(
          Expense(
            id: const Uuid().v4(),
            userId: user.id,
            amount: decision.reconciliation.delta,
            date: DateTime.now(),
            paymentType: 'credit_card',
            paymentRef: widget.card.id,
            description: 'Faltante de deuda',
          ),
        );
      } else if (decision.reconciliation.action == CardDebtAdjustmentAction.cardPayment) {
        await paymentRepo.insert(
          CardPayment(
            id: const Uuid().v4(),
            cardId: widget.card.id,
            amount: decision.reconciliation.delta,
            date: DateTime.now(),
          ),
        );
      }
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'credit_cards.validate_debt', details: {'card_id': widget.card.id});
      _showSaveError('No pudimos guardar el ajuste de la deuda. Prueba de nuevo.');
      return;
    }

    if (!mounted) return;
    setState(() {});
    ref.invalidate(expensesListProvider);
    ref.invalidate(dashboardDebtProvider);
    ref.invalidate(creditCardsListProvider);
    ref.invalidate(cardPaymentsByCardProvider(widget.card.id));
    ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
          (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'credit_cards.push'),
        );
    final message = switch (decision.reconciliation.action) {
      CardDebtAdjustmentAction.missingExpense =>
        'Se agregó un egreso por faltante de deuda.',
      CardDebtAdjustmentAction.cardPayment =>
        'Se registró un pago por la diferencia.',
      CardDebtAdjustmentAction.none => 'La deuda ya coincide con el cálculo.',
    };
    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editPayment(BuildContext context, CardPayment payment) async {
    final amountC = TextEditingController(text: formatCurrency(payment.amount));
    DateTime selectedDate = payment.date.toLocal();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CurrencyTextField(
                controller: amountC,
                decoration: const InputDecoration(labelText: 'Monto'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(CupertinoIcons.calendar, size: 18),
                label: Text(formatDisplayDate(selectedDate)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialogState(() => selectedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (amountC.text.trim().isNotEmpty) Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || amountC.text.trim().isEmpty) return;
    final amount = parseCurrency(amountC.text);
    if (amount == null || amount <= 0) return;

    // Task 5.5: detect boundary cross before saving
    final now = DateTime.now();
    final configRepo = ref.read(minPaymentConfigRepositoryProvider);
    final config = await configRepo.getForCardAndMonth(widget.card.id, now.year, now.month);
    if (config != null) {
      final clampedDay = clampEffectiveDay(config.effectiveDay, now.year, now.month);
      final cutoff = DateTime(now.year, now.month, clampedDay);
      final oldBeforeCutoff = payment.date.toLocal().isBefore(cutoff);
      final newBeforeCutoff = selectedDate.isBefore(cutoff);
      if (oldBeforeCutoff != newBeforeCutoff && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cambiaste la fecha de este pago — esto afecta el progreso del pago mínimo.',
            ),
          ),
        );
      }
    }

    final payRepo = ref.read(cardPaymentRepositoryProvider);
    try {
      await payRepo.update(CardPayment(
        id: payment.id,
        cardId: payment.cardId,
        amount: amount,
        date: selectedDate,
      ));
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'credit_cards.edit_payment', details: {'payment_id': payment.id});
      _showSaveError('No pudimos guardar el pago. Prueba de nuevo.');
      return;
    }
    if (!mounted) return;
    _refreshMinStatus();
    ref.invalidate(dashboardDebtProvider);
    ref.invalidate(dashboardMinPaymentSummaryProvider);
    ref.invalidate(cardPaymentsByCardProvider(widget.card.id));
    ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
          (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'credit_cards.push'),
        );
  }

  Future<void> _deletePayment(BuildContext context, CardPayment payment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pago'),
        content: Text(
          '¿Eliminar el pago de \$${formatCurrency(payment.amount)} del ${formatDisplayDate(payment.date.toLocal())}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.colors.danger,
              foregroundColor: ctx.colors.onDanger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final payRepo = ref.read(cardPaymentRepositoryProvider);
    try {
      await payRepo.markPendingDelete(payment.id);
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'credit_cards.delete_payment', details: {'payment_id': payment.id});
      _showSaveError('No pudimos eliminar el pago. Prueba de nuevo.');
      return;
    }
    if (!mounted) return;
    _refreshMinStatus();
    ref.invalidate(dashboardDebtProvider);
    ref.invalidate(dashboardMinPaymentSummaryProvider);
    ref.invalidate(cardPaymentsByCardProvider(widget.card.id));
    ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
          (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'credit_cards.push'),
        );
  }
}

enum _PaymentAction { edit, delete }

/// Resumen de la tarjeta sobre papel limpio: franja con el tono del billete
/// de la cuenta (identidad), deuda en rojo cuando hay (estado) y los datos fijos.
class _CardSummary extends StatelessWidget {
  const _CardSummary({
    required this.card,
    required this.hue,
    required this.hideValues,
    required this.debtFuture,
  });

  final CreditCard card;
  final Color hue;
  final bool hideValues;
  final Future<double> debtFuture;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final labelStyle = t.labelLarge?.copyWith(color: c.textMuted, fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: c.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Container(
                  key: const ValueKey('card-summary-hue'),
                  height: 6,
                  color: card.isActive ? hue : hue.withValues(alpha: 0.35),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!card.isActive) ...[
                      Text('Desactivada', style: labelStyle),
                      const SizedBox(height: 8),
                    ],
                    Text('Deuda total', style: labelStyle),
                    const SizedBox(height: 4),
                    FutureBuilder<double>(
                      future: debtFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final debt = snapshot.data ?? 0;
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '\$${formatCurrencyDisplay(debt, hideValues)}',
                            maxLines: 1,
                            style: t.headlineSmall?.copyWith(
                              color: debt > 0 ? c.danger : c.ink,
                              fontWeight: FontWeight.w800,
                              fontFeatures: kTabularFigures,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Corte el día ${card.cutOffDay} · Cuota de manejo \$${formatCurrencyDisplay(card.managementFee, hideValues)}',
                      style: t.bodySmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de un pago con su menú de editar y eliminar.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.amount,
    required this.date,
    required this.onEdit,
    required this.onDelete,
  });

  final String amount;
  final String date;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    amount,
                    style: t.titleSmall?.copyWith(color: c.ink, fontWeight: FontWeight.w700, fontFeatures: kTabularFigures),
                  ),
                  Text(date, style: t.bodySmall?.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            PopupMenuButton<_PaymentAction>(
              tooltip: 'Opciones del pago',
              icon: Icon(CupertinoIcons.ellipsis, color: c.textMuted),
              onSelected: (action) => action == _PaymentAction.edit ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _PaymentAction.edit,
                  child: ListTile(
                    leading: Icon(CupertinoIcons.pencil),
                    title: Text('Editar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _PaymentAction.delete,
                  child: ListTile(
                    leading: Icon(CupertinoIcons.delete, color: c.danger),
                    title: Text('Eliminar', style: TextStyle(color: c.danger)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentFilterBar extends StatelessWidget {
  const _PaymentFilterBar({
    required this.selected,
    required this.onSelected,
    required this.onPickCustomRange,
  });

  final CardPaymentDateFilter selected;
  final void Function(CardPaymentDateFilter filter) onSelected;
  final Future<void> Function() onPickCustomRange;

  @override
  Widget build(BuildContext context) {
    const filters = [
      CardPaymentDateFilter.today,
      CardPaymentDateFilter.yesterday,
      CardPaymentDateFilter.thisWeek,
      CardPaymentDateFilter.last30Days,
      CardPaymentDateFilter.currentMonth,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ...filters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f.label),
                  selected: selected.type == f.type,
                  onSelected: (_) => onSelected(f),
                ),
              )),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Rango personalizado'),
              selected: selected.type == CardPaymentDateFilterType.custom,
              onSelected: (_) => onPickCustomRange(),
            ),
          ),
        ],
      ),
    );
  }
}
