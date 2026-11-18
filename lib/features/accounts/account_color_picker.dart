import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/theme/account_hues.dart';
import 'package:perfinance/core/theme/app_colors.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';

/// Nombres de los tonos de billete, en el orden de [AppColors.noteHues].
const noteHueNames = ['Verde', 'Azul', 'Naranja', 'Café', 'Rosado'];

/// Color que muestra el formulario: el elegido o, si no hay, el automático
/// (el que ya tiene la cuenta, o el que le tocaría a una cuenta nueva).
int displayedColorSlot(WidgetRef ref, {required String? accountId, required int? chosen}) {
  if (chosen != null) return chosen;
  final slots = ref.watch(accountHueSlotsProvider).valueOrNull ?? const <String, int>{};
  if (accountId != null && slots[accountId] != null) return slots[accountId]! % noteHueCount;
  return slots.length % noteHueCount;
}

/// Elegir el color de una tarjeta o cuenta de ahorro: los cinco billetes en
/// su proporción, el elegido con marco y check. El color solo identifica la
/// cuenta; nunca dice si va bien o mal.
class AccountColorPicker extends StatelessWidget {
  const AccountColorPicker({super.key, required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color', style: t.labelLarge?.copyWith(color: c.ink)),
        const SizedBox(height: 4),
        Text(
          'Te ayuda a reconocer la cuenta en las listas.',
          style: t.bodySmall?.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < noteHueCount; i++)
              _Swatch(
                color: c.noteHues[i],
                name: noteHueNames[i],
                selected: i == selected,
                onTap: () => onChanged(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.name, required this.selected, required this.onTap});

  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: 'Color $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 52,
          height: 44,
          child: Center(
            // Billete en proporción; el elegido lleva un marco de 2pt en tinta.
            child: Container(
              width: 42,
              height: 30,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: selected ? c.ink : Colors.transparent, width: 2),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                // El papel contrasta con el billete en claro y en oscuro.
                child: selected ? Icon(CupertinoIcons.checkmark_alt, size: 16, color: c.surface) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
