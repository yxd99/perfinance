import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_theme.dart';

/// Grupo inset de iOS sobre papel limpio: esquinas de 12pt y filetes de 0,5pt
/// entre filas, sangrados 16pt.
class InsetListGroup extends StatelessWidget {
  const InsetListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: c.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 16, color: c.divider),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Encabezado de sección en mayúsculas sobre un grupo inset.
class InsetSectionHeader extends StatelessWidget {
  const InsetSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.colors.textMuted,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
