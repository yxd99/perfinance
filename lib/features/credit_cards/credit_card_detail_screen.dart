import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/card_payment.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/models/min_payment_config.dart';
import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/data/repositories/min_payment_config_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/card_debt_validation_dialog.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/services/card_debt_reconciliation_service.dart';
import 'package:perfinance/services/min_payment_service.dart';
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
          return const Scaffold(body: Center(child: Text('Tarjeta no encontrada')));
        }
        return _DetailContent(card: card);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.credit_card_off, size: 48, color: Theme.of(context).colorScheme.error),
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
  Future<MinPaymentStatus?> _getMinStatus() async {
    final repo = ref.read(minPaymentConfigRepositoryProvider);
    final payRepo = ref.read(cardPaymentRepositoryProvider);
    return MinPaymentService.getStatus(repo, payRepo, widget.card.id);
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

  @override
  Widget build(BuildContext context) {
    final hideValues = ref.watch(hideValuesProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(widget.card.alias)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Corte día ${widget.card.cutOffDay}', style: Theme.of(context).textTheme.titleSmall),
                  Text('Cuota de manejo: \$${formatCurrencyDisplay(widget.card.managementFee, hideValues)}'),
                  const SizedBox(height: 16),
                  FutureBuilder<double>(
                    future: _getCurrentDebt(),
                    builder: (context, snapshot) {
                      final debt = snapshot.data ?? 0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Deuda total', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 4),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const LinearProgressIndicator()
                          else
                            Text(
                              '\$${formatCurrencyDisplay(debt, hideValues)}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<MinPaymentStatus?>(
            future: _getMinStatus(),
            builder: (context, snap) {
              final status = snap.data;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pago mínimo', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (status == null)
                        const Text('Sin configurar')
                      else if (status.pending <= 0)
                        const Text('Estás al día', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                      else
                        Text('Pendiente: \$${formatCurrencyDisplay(status.pending, hideValues)}'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _setMinPayment(context),
                            child: Text(status == null ? 'Configurar pago mínimo' : 'Editar pago mínimo'),
                          ),
                          TextButton(
                            onPressed: () => _registerPayment(context),
                            child: const Text('Registrar pago'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _validateCurrentDebt(context),
                        child: const Text('Validar deuda actual'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _setMinPayment(BuildContext context) async {
    final now = DateTime.now();
    final repo = ref.read(minPaymentConfigRepositoryProvider);
    final existing = await repo.getForCardAndMonth(widget.card.id, now.year, now.month);
    if (!context.mounted) return;
    final c = TextEditingController();
    if (existing != null) {
      c.text = formatCurrency(existing.amount);
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Editar pago mínimo' : 'Pago mínimo'),
        content: CurrencyTextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
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
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    final amount = parseCurrency(c.text);
    if (amount == null || amount < 0) return;
    final config = MinPaymentConfig(
      id: existing?.id ?? const Uuid().v4(),
      cardId: widget.card.id,
      amount: amount,
      year: now.year,
      month: now.month,
    );
    if (existing != null) {
      await repo.update(config);
    } else {
      await repo.insert(config);
    }
    if (mounted) {
      setState(() {});
      ref.invalidate(creditCardsListProvider);
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
          decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
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
    await payRepo.insert(CardPayment(
      id: const Uuid().v4(),
      cardId: widget.card.id,
      amount: amount,
      date: DateTime.now(),
    ));
    if (mounted) {
      setState(() {});
      ref.invalidate(dashboardDebtProvider);
      ref.invalidate(creditCardsListProvider);
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

    if (!mounted) return;
    setState(() {});
    ref.invalidate(expensesListProvider);
    ref.invalidate(dashboardDebtProvider);
    ref.invalidate(creditCardsListProvider);
    final message = switch (decision.reconciliation.action) {
      CardDebtAdjustmentAction.missingExpense =>
        'Se agregó un egreso por faltante de deuda.',
      CardDebtAdjustmentAction.cardPayment =>
        'Se registró un pago por la diferencia.',
      CardDebtAdjustmentAction.none => 'La deuda ya coincide con el cálculo.',
    };
    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(message)));
  }
}
