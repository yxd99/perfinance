import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_colors.dart';

export 'package:perfinance/core/theme/app_colors.dart';

/// Rutas de assets de la app.
abstract class AppAssets {
  static const String logo = 'assets/images/perfinance-logo.png';
}

/// Fondos decorativos que todavía no tienen rol semántico (login y onboarding).
/// Los colores de interfaz van en [AppColors].
abstract class AppThemeColors {
  /// Papel moneda en degradado suave para fondos claros.
  static const LinearGradient backgroundGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF4EFE3),
      Color(0xFFEFE8D8),
    ],
  );
}

/// Cifras de montos: tabulares para que las columnas alineen.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

/// Tema de la app (mundo «Billete»). Los colores salen de [AppColors]; acá solo
/// se mapean a Material. La tipografía es la del sistema (SF Pro en iOS) para
/// respetar Dynamic Type.
class AppTheme {
  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accent,
      secondary: c.info,
      tertiary: c.warning,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.textMuted,
      outline: c.divider,
      outlineVariant: c.divider,
      surfaceContainerHighest: c.track,
    );
    final base = ThemeData(brightness: brightness, useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      extensions: [c],
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      dividerTheme: DividerThemeData(color: c.divider, thickness: 0.5, space: 0.5),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.canvas,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.divider, width: 0.5),
        ),
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textMuted,
        textColor: c.ink,
        minVerticalPadding: 10,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accentSoft,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.accent : c.textMuted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.accent : c.textMuted,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(borderRadius: BorderRadius.circular(10), color: c.accent),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: c.onAccent,
        unselectedLabelColor: c.textMuted,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.surface,
        selectedColor: c.accentSoft,
        side: BorderSide(color: c.divider),
        labelStyle: TextStyle(color: c.ink),
        checkmarkColor: c.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.divider,
      ),
      textTheme: _textTheme(base.textTheme, c),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Escala del sistema con pesos ajustados; sin tamaños fijos fuera de la
  /// escala para que Dynamic Type siga funcionando.
  static TextTheme _textTheme(TextTheme t, AppColors c) {
    return t
        .copyWith(
          displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1, fontFeatures: kTabularFigures),
          headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
          headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
          titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0),
          labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0),
          // Material agrega tracking a cuerpo y etiquetas; SF Pro ya trae el suyo.
          titleSmall: t.titleSmall?.copyWith(letterSpacing: 0),
          bodyLarge: t.bodyLarge?.copyWith(letterSpacing: 0),
          bodyMedium: t.bodyMedium?.copyWith(letterSpacing: 0),
          bodySmall: t.bodySmall?.copyWith(letterSpacing: 0),
          labelMedium: t.labelMedium?.copyWith(letterSpacing: 0),
          labelSmall: t.labelSmall?.copyWith(letterSpacing: 0),
        )
        .apply(bodyColor: c.ink, displayColor: c.ink);
  }
}
