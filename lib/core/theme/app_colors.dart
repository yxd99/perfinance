import 'package:flutter/material.dart';

/// Colores semánticos de la app. Las pantallas usan roles (`context.colors.danger`),
/// nunca valores sueltos, así un cambio de identidad solo toca este archivo.
///
/// Cada par texto/fondo cumple WCAG AA (4.5:1 texto, 3:1 controles) en ambos temas.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.positive,
    required this.positiveSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.onDanger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.textMuted,
    required this.divider,
    required this.track,
    required this.shadow,
    required this.heroGradient,
    required this.heroDebtGradient,
    required this.onHero,
    required this.onHeroMuted,
    required this.onHeroSoft,
    required this.canvas,
    required this.surface,
    required this.ink,
    required this.noteHues,
  });

  /// Acción principal, selección e íconos/textos de acento.
  final Color accent;

  /// Texto e íconos sobre [accent].
  final Color onAccent;

  /// Fondo tintado para chips, resúmenes y avatares de acento.
  final Color accentSoft;

  /// Buenas noticias: al día, cobrado, baja de gasto.
  final Color positive;
  final Color positiveSoft;

  /// Atención sin urgencia: atrasos, ajustes pendientes, sin conexión.
  final Color warning;
  final Color warningSoft;

  /// Malas noticias o destructivo: deuda, aumento de gasto, borrar.
  final Color danger;
  final Color onDanger;
  final Color dangerSoft;

  /// Información neutral: cuentas no-tarjeta, deudas recibidas.
  final Color info;
  final Color infoSoft;

  /// Texto secundario sobre superficies neutras.
  final Color textMuted;
  final Color divider;

  /// Fondo de barras de progreso.
  final Color track;
  final Color shadow;

  /// Fondos de las tarjetas destacadas (tarjeta de crédito, resumen) y de deuda.
  final LinearGradient heroGradient;
  final LinearGradient heroDebtGradient;

  /// Texto e íconos sobre los gradientes hero.
  final Color onHero;
  final Color onHeroMuted;

  /// Chips y círculos translúcidos sobre los gradientes hero.
  final Color onHeroSoft;

  /// Fondo de la app (papel moneda) y superficie elevada (tarjetas, hojas).
  final Color canvas;
  final Color surface;

  /// Texto principal.
  final Color ink;

  /// Tonos de los billetes colombianos (serie 2016) para identificar cuentas.
  /// Son identidad, no estado: nunca comunican éxito, alerta o error.
  final List<Color> noteHues;

  /// Color de una cuenta según su posición (ver `assignHueSlots`). Si la cuenta
  /// no tiene posición (todavía no cargó, o fue borrada) cae al tono por id.
  Color accountColorFor(String id, Map<String, int> slots) {
    final slot = slots[id];
    return slot == null ? accountColor(id) : noteHues[slot % noteHues.length];
  }

  /// Color estable de una cuenta (tarjeta o medio de pago) según su id.
  Color accountColor(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return noteHues[hash % noteHues.length];
  }

  /// Billete de 50.000: tarjeta del mes y bloques destacados.
  static const _heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B3A7A), Color(0xFF432A5C)],
  );

  static const _heroDebtGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC53030), Color(0xFF8E1F2C)],
  );

  static const light = AppColors(
    accent: Color(0xFF5B3A7A),
    onAccent: Colors.white,
    accentSoft: Color(0xFFECE4F2),
    positive: Color(0xFF18784A),
    positiveSoft: Color(0xFFE3F3EA),
    warning: Color(0xFF8A5300),
    warningSoft: Color(0xFFFFF1D6),
    danger: Color(0xFFC53030),
    onDanger: Colors.white,
    dangerSoft: Color(0xFFFCE9E9),
    info: Color(0xFF1F5F99),
    infoSoft: Color(0xFFE6EFF8),
    textMuted: Color(0xFF5E574C),
    divider: Color(0xFFDCD3C1),
    track: Color(0xFFE6DECD),
    shadow: Color(0x141E1B18),
    heroGradient: _heroGradient,
    heroDebtGradient: _heroDebtGradient,
    onHero: Colors.white,
    onHeroMuted: Color(0xE6FFFFFF),
    onHeroSoft: Color(0x33FFFFFF),
    canvas: Color(0xFFF4EFE3),
    surface: Color(0xFFFBF8F1),
    ink: Color(0xFF1E1B18),
    noteHues: [
      Color(0xFF2F6B4F), // 100.000 verde
      Color(0xFF2C5A8C), // 20.000 azul
      Color(0xFFA85A1C), // 2.000 naranja
      Color(0xFF7A4A2E), // 5.000 café
      Color(0xFF8A3B6E), // 10.000 rosa
    ],
  );

  static const dark = AppColors(
    accent: Color(0xFFC7A6E8),
    onAccent: Color(0xFF24123A),
    accentSoft: Color(0xFF2D2338),
    positive: Color(0xFF4ADE80),
    positiveSoft: Color(0xFF16301F),
    warning: Color(0xFFF5B544),
    warningSoft: Color(0xFF3A2C10),
    danger: Color(0xFFFF7B7B),
    onDanger: Color(0xFF2A0606),
    dangerSoft: Color(0xFF3B1717),
    info: Color(0xFF7FB8F0),
    infoSoft: Color(0xFF15263A),
    textMuted: Color(0xFFA89F8F),
    divider: Color(0xFF38322A),
    track: Color(0xFF38322A),
    shadow: Color(0x4D000000),
    heroGradient: _heroGradient,
    heroDebtGradient: _heroDebtGradient,
    onHero: Colors.white,
    onHeroMuted: Color(0xE6FFFFFF),
    onHeroSoft: Color(0x33FFFFFF),
    canvas: Color(0xFF14120F),
    surface: Color(0xFF221E19),
    ink: Color(0xFFEDE6D6),
    noteHues: [
      Color(0xFF6FBF94),
      Color(0xFF7FA8DB),
      Color(0xFFE39A5B),
      Color(0xFFC49170),
      Color(0xFFD08AB8),
    ],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppColorsContext on BuildContext {
  /// Colores semánticos del tema actual.
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
