import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_theme.dart';

/// Marca de PerFinance en el mundo Billete: un billete morado de 50.000 en
/// miniatura (con grabado guilloché y la «P» como denominación) junto al
/// nombre en tinta. Se dibuja en código para respetar modo oscuro y escala.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 56, this.showWordmark = true});

  /// Alto del billete; el nombre escala con él.
  final double height;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final note = BrandNote(height: height);
    if (!showWordmark) return note;
    return Semantics(
      label: 'PerFinance',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          note,
          SizedBox(width: height * 0.28),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Per', style: TextStyle(color: c.ink)),
                TextSpan(text: 'Finance', style: TextStyle(color: c.accent)),
              ],
            ),
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: height * 0.62,
              fontWeight: FontWeight.w800,
              letterSpacing: -height * 0.018,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Solo el billete: sirve como ícono de la marca.
class BrandNote extends StatelessWidget {
  const BrandNote({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: height,
      width: height * 1.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: c.heroGradient,
          borderRadius: BorderRadius.circular(height * 0.14),
        ),
        child: CustomPaint(
          painter: _NotePainter(line: c.onHeroSoft, ink: c.onHero),
        ),
      ),
    );
  }
}

class _NotePainter extends CustomPainter {
  _NotePainter({required this.line, required this.ink});

  final Color line;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(h * 0.14)));

    // Grabado: círculos concéntricos desde la roseta, como el fondo del billete del mes.
    final rosette = Offset(size.width * 0.66, h * 0.5);
    final guilloche = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, h * 0.012);
    for (var r = h * 0.08; r < size.width; r += h * 0.075) {
      canvas.drawCircle(rosette, r, guilloche);
    }

    // Roseta: anillo de lazos alrededor de la denominación.
    final ring = Paint()
      ..color = ink.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, h * 0.018);
    final rr = h * 0.3;
    const loops = 14;
    for (var i = 0; i < loops; i++) {
      final a = i * 2 * math.pi / loops;
      canvas.drawCircle(rosette + Offset(math.cos(a), math.sin(a)) * rr, h * 0.075, ring);
    }
    canvas.drawCircle(rosette, rr * 0.72, Paint()..color = const Color(0x33000000));
    canvas.restore();

    // Denominación «P».
    final tp = TextPainter(
      text: TextSpan(
        text: 'P',
        style: TextStyle(color: ink, fontSize: h * 0.42, fontWeight: FontWeight.w800, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rosette - Offset(tp.width / 2, tp.height / 2));

    // Esquina de valor, como el numeral pequeño de un billete.
    final corner = TextPainter(
      text: TextSpan(
        text: '\$',
        style: TextStyle(color: ink.withValues(alpha: 0.85), fontSize: h * 0.2, fontWeight: FontWeight.w700, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    corner.paint(canvas, Offset(h * 0.13, h * 0.11));
  }

  @override
  bool shouldRepaint(_NotePainter old) => old.line != line || old.ink != ink;
}
