/// Configuración de Sentry desde compilación (`--dart-define` / `--dart-define-from-file`).
/// Sin `SENTRY_DSN` el reporte de errores queda desactivado (útil en desarrollo y tests).
class SentryConfig {
  SentryConfig._();

  static const String dsn = String.fromEnvironment('SENTRY_DSN');
  static const String environment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isConfigured => dsn.isNotEmpty;
}
