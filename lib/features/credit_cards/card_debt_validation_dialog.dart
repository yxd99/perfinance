import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/services/card_debt_reconciliation_service.dart';

class CardDebtValidationDecision {
  const CardDebtValidationDecision({
    required this.actualDebt,
    required this.reconciliation,
  });

  final double actualDebt;
  final CardDebtReconciliationResult reconciliation;
}

Future<CardDebtValidationDecision?> showCardDebtValidationDialog({
  required BuildContext context,
  required double expectedDebt,
  String title = 'Validar deuda',
}) {
  return showDialog<CardDebtValidationDecision>(
    context: context,
    builder: (_) => _CardDebtValidationDialog(expectedDebt: expectedDebt, title: title),
  );
}

class _CardDebtValidationDialog extends StatefulWidget {
  const _CardDebtValidationDialog({required this.expectedDebt, required this.title});

  final double expectedDebt;
  final String title;

  @override
  State<_CardDebtValidationDialog> createState() => _CardDebtValidationDialogState();
}

class _CardDebtValidationDialogState extends State<_CardDebtValidationDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: formatCurrency(widget.expectedDebt));
  late double _actualDebt = parseCurrency(_controller.text) ?? widget.expectedDebt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    setState(() {
      _actualDebt = parseCurrency(_controller.text) ?? widget.expectedDebt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final expectedDebt = widget.expectedDebt;
    final reconciliation = CardDebtReconciliationService.reconcile(
      expectedDebt: expectedDebt,
      actualDebt: _actualDebt,
    );
    final deltaColor = switch (reconciliation.action) {
      CardDebtAdjustmentAction.missingExpense => context.colors.warning,
      CardDebtAdjustmentAction.cardPayment => context.colors.positive,
      CardDebtAdjustmentAction.none => context.colors.accent,
    };
    // Fondo suave del mismo estado: los pares de tokens ya cumplen AA.
    final deltaSoft = switch (reconciliation.action) {
      CardDebtAdjustmentAction.missingExpense => context.colors.warningSoft,
      CardDebtAdjustmentAction.cardPayment => context.colors.positiveSoft,
      CardDebtAdjustmentAction.none => context.colors.accentSoft,
    };
    final deltaLabel = switch (reconciliation.action) {
      CardDebtAdjustmentAction.missingExpense => 'Faltante detectado',
      CardDebtAdjustmentAction.cardPayment => 'Pago a registrar',
      CardDebtAdjustmentAction.none => 'Deuda conciliada',
    };
    final helperText = switch (reconciliation.action) {
      CardDebtAdjustmentAction.missingExpense =>
        'La deuda real es mayor que la calculada. Se agregará un egreso extra con la descripción Faltante de deuda.',
      CardDebtAdjustmentAction.cardPayment =>
        'La deuda real es menor que la calculada. Se registrará un pago de tarjeta por la diferencia.',
      CardDebtAdjustmentAction.none => 'La deuda ingresada coincide con el cálculo actual. No se crearán movimientos adicionales.',
    };
    final confirmLabel = switch (reconciliation.action) {
      CardDebtAdjustmentAction.missingExpense => 'Agregar faltante',
      CardDebtAdjustmentAction.cardPayment => 'Registrar pago',
      CardDebtAdjustmentAction.none => 'Confirmar deuda',
    };

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirma si el saldo real de la tarjeta coincide con el cálculo actual.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DebtSummaryCard(
                    label: 'Calculada',
                    value: '\$${formatCurrency(expectedDebt)}',
                    icon: CupertinoIcons.function,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DebtSummaryCard(
                    label: deltaLabel,
                    value: reconciliation.action == CardDebtAdjustmentAction.none
                        ? 'Sin ajuste'
                        : '\$${formatCurrency(reconciliation.delta)}',
                    icon: reconciliation.action == CardDebtAdjustmentAction.cardPayment
                        ? CupertinoIcons.arrow_down
                        : reconciliation.action == CardDebtAdjustmentAction.missingExpense
                            ? CupertinoIcons.arrow_up
                            : CupertinoIcons.checkmark_circle,
                    valueColor: deltaColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CurrencyTextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                labelText: 'Deuda real actual',
                helperText: 'Puedes dejar el valor calculado si ya está bien.',
              ),
              validator: (value) {
                final parsed = parseCurrency(value ?? '');
                if (parsed == null || parsed < 0) return 'Escribe un monto válido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: deltaSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resultado',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: deltaColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(helperText),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = parseCurrency(_controller.text);
            if (parsed == null || parsed < 0) return;
            Navigator.pop(
              context,
              CardDebtValidationDecision(
                actualDebt: parsed,
                reconciliation: CardDebtReconciliationService.reconcile(
                  expectedDebt: expectedDebt,
                  actualDebt: parsed,
                ),
              ),
            );
          },
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class _DebtSummaryCard extends StatelessWidget {
  const _DebtSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.track,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? c.ink,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
