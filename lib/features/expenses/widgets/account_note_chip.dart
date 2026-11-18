import 'package:flutter/material.dart';

/// Billete en miniatura con el tono de la cuenta (`context.colors.accountColor`).
/// Es identidad, no estado; los lectores de pantalla lo ignoran.
class AccountNoteChip extends StatelessWidget {
  const AccountNoteChip({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 22,
        height: 14,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}
