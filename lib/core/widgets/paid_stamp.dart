import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_theme.dart';

/// Sello de tinta para lo que ya se cerró (deuda pagada, cobro saldado).
///
/// En el mundo Billete lo pagado no desaparece: queda sellado. Es estado, así
/// que usa el color `positive`, nunca un tono de billete.
class PaidStamp extends StatelessWidget {
  const PaidStamp({super.key, required this.label});

  /// Texto del sello, p. ej. «Pagada» o «Saldada».
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Transform.rotate(
        angle: -4 * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: c.positive, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label.toUpperCase(),
            style: t.labelSmall?.copyWith(
              color: c.positive,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
