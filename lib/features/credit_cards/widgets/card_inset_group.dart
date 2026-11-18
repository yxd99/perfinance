import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_theme.dart';

/// Grupo inset de iOS sobre papel limpio, con encabezado opcional en
/// mayúsculas y separadores finos entre filas.
class CardInsetGroup extends StatelessWidget {
  const CardInsetGroup({
    super.key,
    required this.children,
    this.header,
    this.dividerIndent = 16,
  });

  final List<Widget> children;
  final String? header;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                header: true,
                child: Text(
                  header!.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: c.textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
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
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) Divider(height: 1, thickness: 0.5, indent: dividerIndent, color: c.divider),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de acción en el tinte de la app (o en rojo si destruye algo).
class CardActionRow extends StatelessWidget {
  const CardActionRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = destructive ? c.danger : c.accent;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de dato: etiqueta a la izquierda y valor a la derecha en cifras
/// tabulares. El valor puede llevar un color de estado.
class CardInfoRow extends StatelessWidget {
  const CardInfoRow({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 2,
          children: [
            Text(label, style: t.bodyLarge?.copyWith(color: c.ink)),
            Text(
              value,
              style: t.titleSmall?.copyWith(
                color: valueColor ?? c.ink,
                fontWeight: FontWeight.w700,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
