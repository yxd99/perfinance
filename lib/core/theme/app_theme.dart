import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:perfinance/core/theme/app_colors.dart';

export 'package:perfinance/core/theme/app_colors.dart';

/// Rutas de assets de la app.
abstract class AppAssets {
  static const String logo = 'assets/images/perfinance-logo.png';
}

/// Fondos decorativos que todavía no tienen rol semántico (login y onboarding).
/// Los colores de interfaz van en [AppColors].
abstract class AppThemeColors {
  /// Gradiente suave para fondos claros.
  static const LinearGradient backgroundGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF0F9F4),
      Color(0xFFE8F5EE),
      Color(0xFFFFFFFF),
    ],
  );
}

/// Tema de la app. Los colores salen de [AppColors]; acá solo se mapean a Material.
class AppTheme {
  static const Color _surfaceDark = Color(0xFF1C1C1E);
  static const Color _backgroundDark = Color(0xFF0D0D0D);

  static ColorScheme _scheme(AppColors c, Brightness brightness, Color surface) {
    return ColorScheme.fromSeed(
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
      surface: surface,
      onSurfaceVariant: c.textMuted,
      outlineVariant: c.divider,
    );
  }

  static TabBarThemeData _tabBarTheme(AppColors c) {
    return TabBarThemeData(
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: c.accent,
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: c.onAccent,
      unselectedLabelColor: c.textMuted,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
  }

  static ThemeData get light {
    const c = AppColors.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme(c, Brightness.light, Colors.white),
      extensions: const [AppColors.light],
      scaffoldBackgroundColor: const Color(0xFFF4FBF7),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 8,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black26,
      ),
      cardTheme: CardThemeData(
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      tabBarTheme: _tabBarTheme(c),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          shadowColor: c.shadow,
        ),
      ),
      textTheme: _buildTextTheme(Brightness.light),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get dark {
    const c = AppColors.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme(c, Brightness.dark, _surfaceDark),
      extensions: const [AppColors.dark],
      scaffoldBackgroundColor: _backgroundDark,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 8,
        backgroundColor: _backgroundDark,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 6,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: _surfaceDark,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      tabBarTheme: _tabBarTheme(c),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceDark,
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness).textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(base).copyWith(
      headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
      labelLarge: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    );
  }
}
