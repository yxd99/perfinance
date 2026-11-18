import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_theme.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.exclamationmark_circle, size: 40, color: context.colors.danger),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(CupertinoIcons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
