import 'package:flutter/material.dart';

const _confirmWord = 'ELIMINAR';

/// Pide escribir ELIMINAR para confirmar. Devuelve true solo si el usuario
/// confirmó.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  return confirmed ?? false;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se borran tu cuenta y todos tus datos: egresos, tarjetas, ahorros, '
              'deudas, cobros, pagos automáticos y conversaciones con el asesor. '
              'Esto no se puede deshacer.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Las personas que te deben dejan de ver esas deudas en su app. '
              'Las deudas que tienes con otros usuarios siguen siendo de ellos.',
            ),
            const SizedBox(height: 16),
            const Text('Escribe $_confirmWord para confirmar.'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: _confirmWord),
              onChanged: (value) => setState(
                () => _matches = value.trim().toUpperCase() == _confirmWord,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Eliminar cuenta'),
        ),
      ],
    );
  }
}
