/// Convierte excepciones técnicas en mensajes amigables para el usuario.
class UserFriendlyErrors {
  UserFriendlyErrors._();

  /// Mensaje genérico cuando algo falla al cargar.
  static const String loadFailed = 'No se pudo cargar. Revisa tu conexión e intenta de nuevo.';

  /// Mensaje cuando falla la sincronización.
  static const String syncFailed = 'No se pudo sincronizar. Comprueba tu conexión y vuelve a intentarlo.';

  /// Mensaje cuando falla el inicio de sesión.
  static const String loginFailed = 'No pudimos iniciar sesión. Revisa tu correo y contraseña.';

  /// Mensaje cuando falla el registro.
  static const String registerFailed = 'No pudimos crear tu cuenta. Inténtalo de nuevo más tarde.';

  /// Mensaje cuando falla cargar egresos.
  static const String expensesLoadFailed = 'No se pudieron cargar los egresos. Tira a actualizar para reintentar.';

  /// Mensaje cuando falla cargar deudas.
  static const String debtsLoadFailed = 'No se pudieron cargar las deudas. Tira a actualizar para reintentar.';

  /// Mensaje cuando falla cargar el dashboard.
  static const String dashboardLoadFailed = 'No se pudo cargar el resumen. Tira a actualizar para reintentar.';

  /// Mensaje cuando falla cargar tarjetas.
  static const String cardsLoadFailed = 'No se pudieron cargar las tarjetas. Tira a actualizar para reintentar.';

  /// Mensaje cuando falla cargar medios de pago/ahorros.
  static const String savingsLoadFailed = 'No se pudieron cargar los medios de pago. Tira a actualizar para reintentar.';

  /// Convierte un error de auth (Exception o mensaje de Supabase) en texto amigable.
  static String authMessage(Object? error, {required bool isLogin}) {
    if (error == null) return isLogin ? loginFailed : registerFailed;
    final msg = error.toString().toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid_credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (msg.contains('email') && msg.contains('confirm')) {
      return 'Revisa tu correo y confirma tu cuenta antes de iniciar sesión.';
    }
    if (msg.contains('network') || msg.contains('connection') || msg.contains('socket')) {
      return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
    }
    if (msg.contains('user already registered') || msg.contains('already registered')) {
      return 'Ya existe una cuenta con este correo. Inicia sesión o usa otro correo.';
    }
    if (msg.contains('password') || msg.contains('weak')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return isLogin ? loginFailed : registerFailed;
  }

  /// Mensaje genérico para errores de carga (AsyncValue.error).
  static String fromAsyncError(Object? error, [String fallback = loadFailed]) {
    if (error == null) return fallback;
    final msg = error.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('connection') || msg.contains('socket')) {
      return 'Sin conexión. Comprueba tu internet e intenta de nuevo.';
    }
    if (msg.contains('database') || msg.contains('sql')) {
      return 'Hubo un problema con los datos. Cierra la app y ábrela de nuevo.';
    }
    return fallback;
  }
}
