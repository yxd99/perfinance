import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/features/accounts/account_color_picker.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/features/credit_cards/credit_card_delete.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:uuid/uuid.dart';

class CreditCardFormScreen extends ConsumerStatefulWidget {
  final CreditCard? editCard;

  const CreditCardFormScreen({super.key, this.editCard});

  /// Lo que devuelve la ruta cuando la tarjeta se eliminó desde el formulario,
  /// para que el detalle que lo abrió también se cierre.
  static const deletedResult = 'deleted';

  @override
  ConsumerState<CreditCardFormScreen> createState() => _CreditCardFormScreenState();
}

class _CreditCardFormScreenState extends ConsumerState<CreditCardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  final _cutOffController = TextEditingController();
  final _feeController = TextEditingController();

  /// Color elegido; null mientras el usuario no lo cambie (queda el automático).
  int? _colorSlot;

  @override
  void initState() {
    super.initState();
    if (widget.editCard != null) {
      _colorSlot = widget.editCard!.colorSlot;
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
              decoration: const InputDecoration(labelText: 'Alias', hintText: 'Ej.: Visa Bancolombia'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Escribe un alias' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cutOffController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Día de corte (1-31)'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Escribe el día de corte';
                final n = int.tryParse(v);
                if (n == null || n < 1 || n > 31) return 'Tiene que ser un día entre 1 y 31';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CurrencyTextField(
              controller: _feeController,
              decoration: const InputDecoration(labelText: 'Cuota de manejo', helperText: 'Escribe 0 si no cobra cuota.'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Escribe la cuota (0 si no tiene)';
                final val = parseCurrency(v);
                if (val == null || val < 0) return 'Escribe un monto válido';
                return null;
              },
            ),
            const SizedBox(height: 20),
            AccountColorPicker(
              selected: displayedColorSlot(ref, accountId: widget.editCard?.id, chosen: _colorSlot),
              onChanged: (v) => setState(() => _colorSlot = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Guardar tarjeta'),
            ),
            if (widget.editCard != null) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(CupertinoIcons.delete),
                label: const Text('Eliminar tarjeta'),
                style: TextButton.styleFrom(foregroundColor: context.colors.danger, minimumSize: const Size(44, 48)),
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
    final deleted = await confirmAndDeleteCard(context, card);
    if (!deleted || !mounted) return;
    Navigator.of(context).pop(CreditCardFormScreen.deletedResult);
  }

  /// Avisa abajo que algo no se pudo guardar. El error ya se reportó.
  void _showSaveError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      final updated = widget.editCard!.copyWith(alias: alias, cutOffDay: cutOff, managementFee: fee, colorSlot: _colorSlot);
      try {
        await repo.update(updated);
      } catch (e, st) {
        ErrorReporter.capture(e, st, operation: 'credit_cards.update', details: {'card_id': updated.id});
        _showSaveError('No pudimos guardar los cambios. Prueba de nuevo.');
        return;
      }
    } else {
      final card = CreditCard(
        id: const Uuid().v4(),
        userId: user.id,
        alias: alias,
        cutOffDay: cutOff,
        managementFee: fee,
        colorSlot: _colorSlot,
      );
      try {
        await repo.insert(card);
      } catch (e, st) {
        ErrorReporter.capture(e, st, operation: 'credit_cards.create', details: {'card_id': card.id});
        _showSaveError('No pudimos guardar la tarjeta. Prueba de nuevo.');
        return;
      }
      if (mounted) {
        ref.invalidate(creditCardsListProvider);
        ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
              (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'credit_cards.push'),
            );
        Navigator.of(context).pop(card.id);
        return;
      }
    }
    if (mounted) {
      ref.invalidate(creditCardsListProvider);
      ref.read(syncServiceProvider).pushPendingIfOnline().catchError(
            (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'credit_cards.push'),
          );
      Navigator.of(context).pop();
    }
  }
}
