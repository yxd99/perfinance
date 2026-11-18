import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_theme.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glifo suelto, sin círculo de color: el mundo Billete no usa íconos en círculo.
            Icon(icon, size: 40, color: context.colors.textMuted),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(CupertinoIcons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
