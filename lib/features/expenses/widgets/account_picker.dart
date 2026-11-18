import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/theme/app_colors.dart';
import 'package:perfinance/core/widgets/inset_add_row.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/features/expenses/widgets/account_note_chip.dart';

/// Llave del campo «Cuenta» del formulario de egreso.
const accountFieldKey = ValueKey('expense-account-field');

/// Con más cuentas que esto, la hoja muestra el buscador.
const _searchThreshold = 6;

/// Una cuenta con la que se puede pagar un egreso: tarjeta de crédito o cuenta
/// de ahorro (débito, efectivo, otra).
@immutable
class AccountChoice {
  const AccountChoice(this.id, this.label, {required this.isCard});

  final String id;
  final String label;
  final bool isCard;

  String get kindLabel => isCard ? 'Tarjeta de crédito' : 'Cuenta de ahorro';

  @override
  bool operator ==(Object other) =>
      other is AccountChoice && other.id == id && other.label == label && other.isCard == isCard;

  @override
  int get hashCode => Object.hash(id, label, isCard);
}

/// Pedido de crear una cuenta nueva desde la hoja.
enum AccountPickerAdd { card, savings }

String _fold(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString();
}

/// Filtra por nombre sin importar mayúsculas ni tildes («debito» encuentra
/// «Débito Bancolombia»). Conserva el orden de entrada.
List<AccountChoice> filterAccountChoices(List<AccountChoice> all, String query) {
  final q = _fold(query.trim());
  if (q.isEmpty) return all;
  return [for (final a in all) if (_fold(a.label).contains(q)) a];
}

/// Campo «Cuenta» del formulario: muestra la cuenta elegida (o pide elegir) y
/// al tocarlo abre la hoja de cuentas. Reemplaza a los chips, que con muchas
/// tarjetas y cuentas se volvían una pared difícil de recorrer.
class AccountField extends ConsumerWidget {
  const AccountField({super.key = accountFieldKey, required this.selected, required this.onTap, this.errorText});

  final AccountChoice? selected;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final s = selected;
    final hasError = errorText != null;
    return Semantics(
      button: true,
      label: s == null ? 'Cuenta, sin elegir' : 'Cuenta, ${s.label}, ${s.kindLabel}',
      hint: 'Elegir cuenta',
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: hasError ? c.danger : c.divider, width: hasError ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  if (s != null) ...[
                    AccountNoteChip(color: ref.accountHue(context, s.id)),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: s == null
                        ? Text('Elige con qué pagaste', style: t.bodyLarge?.copyWith(color: c.textMuted))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyLarge),
                              Text(s.kindLabel, style: t.bodySmall?.copyWith(color: c.textMuted)),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s == null ? 'Elegir' : 'Cambiar',
                    style: t.labelLarge?.copyWith(color: c.accent, fontWeight: FontWeight.w600),
                  ),
                  Icon(CupertinoIcons.chevron_forward, size: 16, color: c.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja «¿Con qué pagaste?»: las cuentas agrupadas en tarjetas de crédito y
/// cuentas de ahorro, con buscador cuando son muchas. Devuelve la
/// [AccountChoice] elegida, un [AccountPickerAdd] para crear una, o null.
Future<Object?> showAccountPicker(
  BuildContext context, {
  required List<AccountChoice> options,
  AccountChoice? selected,
}) {
  return showModalBottomSheet<Object>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AccountPickerSheet(options: options, selected: selected),
  );
}

class _AccountPickerSheet extends ConsumerStatefulWidget {
  const _AccountPickerSheet({required this.options, required this.selected});

  final List<AccountChoice> options;
  final AccountChoice? selected;

  @override
  ConsumerState<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends ConsumerState<_AccountPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final searching = _query.trim().isNotEmpty;
    final visible = filterAccountChoices(widget.options, _query);
    final cards = [for (final a in visible) if (a.isCard) a];
    final savings = [for (final a in visible) if (!a.isCard) a];
    final showSearch = widget.options.length > _searchThreshold;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(header: true, child: Text('¿Con qué pagaste?', style: t.titleLarge)),
                  ),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ],
              ),
            ),
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: CupertinoSearchTextField(
                  placeholder: 'Buscar tarjeta o cuenta',
                  padding: const EdgeInsetsDirectional.fromSTEB(6, 12, 6, 12),
                  backgroundColor: c.track,
                  itemColor: c.textMuted,
                  style: t.bodyLarge?.copyWith(color: c.ink),
                  placeholderStyle: t.bodyLarge?.copyWith(color: c.textMuted),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (searching && visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Ninguna cuenta coincide con «${_query.trim()}».',
                        textAlign: TextAlign.center,
                        style: t.bodyLarge?.copyWith(color: c.textMuted),
                      ),
                    ),
                  if (!searching || cards.isNotEmpty)
                    _Section(
                      title: 'TARJETAS DE CRÉDITO',
                      choices: cards,
                      selected: widget.selected,
                      addLabel: searching ? null : 'Agregar tarjeta de crédito',
                      onAdd: () => Navigator.pop(context, AccountPickerAdd.card),
                    ),
                  if (!searching || savings.isNotEmpty)
                    _Section(
                      title: 'CUENTAS DE AHORRO',
                      choices: savings,
                      selected: widget.selected,
                      addLabel: searching ? null : 'Agregar cuenta de ahorro',
                      onAdd: () => Navigator.pop(context, AccountPickerAdd.savings),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends ConsumerWidget {
  const _Section({
    required this.title,
    required this.choices,
    required this.selected,
    required this.addLabel,
    required this.onAdd,
  });

  final String title;
  final List<AccountChoice> choices;
  final AccountChoice? selected;
  final String? addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final rows = <Widget>[
      for (final a in choices) _ChoiceRow(choice: a, selected: a == selected),
      if (addLabel != null) InsetAddRow(label: addLabel!, onTap: onAdd),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: t.labelMedium?.copyWith(color: c.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: c.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 62, color: c.divider),
                  rows[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceRow extends ConsumerWidget {
  const _ChoiceRow({required this.choice, required this.selected});

  final AccountChoice choice;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: choice.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => Navigator.pop(context, choice),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                AccountNoteChip(color: ref.accountHue(context, choice.id)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    choice.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: c.ink,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                ),
                if (selected) Icon(CupertinoIcons.checkmark_alt, size: 20, color: c.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
