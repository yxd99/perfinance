/// Configuración de Supabase desde compilación (`--dart-define` / `--dart-define-from-file`).
/// No incluir secretos en el código; usa `dart_defines.json` local (ignorado por git) o CI secrets.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      url.isNotEmpty && anonKey.isNotEmpty;
}
