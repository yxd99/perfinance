import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_theme.dart';

/// Última fila de una lista agrupada para agregar un elemento («Agregar tarjeta»,
/// «Agregar deudor»…). Es el patrón único de alta dentro de las listas: nada de
/// botones morados de ancho completo arriba o abajo.
class InsetAddRow extends StatelessWidget {
  const InsetAddRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(CupertinoIcons.add, size: 20, color: c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: c.accent, fontWeight: FontWeight.w600),
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
