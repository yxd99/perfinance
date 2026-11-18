import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_theme.dart';

class SummaryTotalBar extends StatelessWidget {
  const SummaryTotalBar({required this.label, required this.amount, super.key});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text(amount, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: c.accent)),
        ],
      ),
    );
  }
}
