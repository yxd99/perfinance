import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_colors.dart';

/// Una acción de una fila (editar, eliminar, marcar como pagada...).
class RowAction {
  const RowAction({required this.label, required this.onSelected, this.icon, this.destructive = false});

  final String label;
  final IconData? icon;
  final FutureOr<void> Function() onSelected;

  /// Se pinta en rojo (eliminar). La confirmación la pide quien la corre.
  final bool destructive;
}

/// Botón «⋯» a la vista al final de una fila. Abre las acciones de esa fila:
/// hoja de acciones de iOS en iPhone y hoja inferior en Android. Reemplaza a
/// los gestos ocultos (mantener presionado, deslizar) como forma principal de
/// llegar a editar o eliminar; deslizar queda solo como atajo.
class RowActionsButton extends StatelessWidget {
  const RowActionsButton({super.key, required this.title, required this.actions});

  /// Nombre de la fila: titula la hoja y el botón para lectores de pantalla.
  final String title;
  final List<RowAction> actions;

  Future<void> _open(BuildContext context) async {
    final platform = Theme.of(context).platform;
    final isCupertino = platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final chosen = isCupertino ? await _showCupertino(context) : await _showMaterial(context);
    // Se corre con la hoja ya cerrada: la acción puede abrir un diálogo o navegar.
    if (chosen != null) await chosen.onSelected();
  }

  Future<RowAction?> _showCupertino(BuildContext context) {
    return showCupertinoModalPopup<RowAction>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final a in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: a.destructive,
              onPressed: () => Navigator.pop(ctx, a),
              child: Text(a.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<RowAction?> _showMaterial(BuildContext context) {
    return showModalBottomSheet<RowAction>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        final c = ctx.colors;
        final t = Theme.of(ctx).textTheme;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(color: c.textMuted),
                ),
              ),
              for (final a in actions)
                ListTile(
                  leading: a.icon == null ? null : Icon(a.icon, color: a.destructive ? c.danger : c.ink),
                  title: Text(
                    a.label,
                    style: TextStyle(color: a.destructive ? c.danger : c.ink, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pop(ctx, a),
                ),
              ListTile(
                title: Text('Cancelar', style: TextStyle(color: c.textMuted)),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Contenedor propio: dentro de una fila tocable no se funde con ella.
    return Semantics(
      container: true,
      button: true,
      label: 'Acciones de $title',
      excludeSemantics: true,
      child: IconButton(
        onPressed: () => _open(context),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: Icon(CupertinoIcons.ellipsis_circle, size: 22, color: c.textMuted),
      ),
    );
  }
}
