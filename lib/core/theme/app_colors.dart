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

  static const _heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF18784A), Color(0xFF125C36)],
  );

  static const _heroDebtGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC53030), Color(0xFF8E1F2C)],
  );

  static const light = AppColors(
    accent: Color(0xFF18784A),
    onAccent: Colors.white,
    accentSoft: Color(0xFFE3F3EA),
    positive: Color(0xFF18784A),
    positiveSoft: Color(0xFFE3F3EA),
    warning: Color(0xFF8A5300),
    warningSoft: Color(0xFFFFF1D6),
    danger: Color(0xFFC53030),
    onDanger: Colors.white,
    dangerSoft: Color(0xFFFCE9E9),
    info: Color(0xFF1F5F99),
    infoSoft: Color(0xFFE6EFF8),
    textMuted: Color(0xFF5B6660),
    divider: Color(0xFFDDE5E0),
    track: Color(0xFFE1E8E4),
    shadow: Color(0x14000000),
    heroGradient: _heroGradient,
    heroDebtGradient: _heroDebtGradient,
    onHero: Colors.white,
    onHeroMuted: Color(0xE6FFFFFF),
    onHeroSoft: Color(0x33FFFFFF),
  );

  static const dark = AppColors(
    accent: Color(0xFF2ECC71),
    onAccent: Color(0xFF06210F),
    accentSoft: Color(0xFF16301F),
    positive: Color(0xFF4ADE80),
    positiveSoft: Color(0xFF16301F),
    warning: Color(0xFFF5B544),
    warningSoft: Color(0xFF3A2C10),
    danger: Color(0xFFFF7B7B),
    onDanger: Color(0xFF2A0606),
    dangerSoft: Color(0xFF3B1717),
    info: Color(0xFF7FB8F0),
    infoSoft: Color(0xFF15263A),
    textMuted: Color(0xFFA3ADA8),
    divider: Color(0xFF2E3330),
    track: Color(0xFF2E3330),
    shadow: Color(0x4D000000),
    heroGradient: _heroGradient,
    heroDebtGradient: _heroDebtGradient,
    onHero: Colors.white,
    onHeroMuted: Color(0xE6FFFFFF),
    onHeroSoft: Color(0x33FFFFFF),
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
