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
  static const String expensesLoadFailed = 'No se pudieron cargar los egresos. Desliza hacia abajo para reintentar.';

  /// Mensaje cuando falla enviar el export de egresos por correo.
  static const String expenseExportEmailFailed =
      'No se pudo enviar el correo con el archivo. Comprueba tu conexión e inténtalo de nuevo.';

  /// Interpreta la excepción de la Edge Function / Resend y evita ocultar el motivo tras un genérico.
  static String expenseExportEmailMessage(Object? error) {
    if (error == null) return expenseExportEmailFailed;
    final raw = error.toString();
    final inner = raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length).trim()
        : raw.trim();
    final lower = inner.toLowerCase();

    if (lower.contains('timeoutexception') ||
        lower.contains('tiempo de espera agotado') ||
        lower.contains('tiempo de espera')) {
      return 'La petición tardó demasiado o quedó bloqueada. Comprueba la conexión e inténtalo de nuevo.';
    }

    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('socket') ||
        lower.contains('failed host lookup') ||
        lower.contains('timed out')) {
      return 'Sin conexión. Comprueba tu internet e inténtalo de nuevo.';
    }

    if (inner.contains('Email not configured on server')) {
      return 'Falta configurar el correo en el servidor: en Supabase → Edge Functions → '
          'Secrets, define RESEND_API_KEY y MAIL_FROM (remitente verificado en Resend).';
    }

    if (inner.contains('NO_USER_SESSION')) {
      return 'No hay sesión activa para llamar al servidor. Cierra la app o vuelve a iniciar sesión e inténtalo de nuevo.';
    }

    if (inner.contains('SESSION_REFRESH_FAILED')) {
      return 'La sesión caducó o no se pudo renovar. Vuelve a iniciar sesión en la app e inténtalo de nuevo.';
    }

    if (inner.contains('Unable to resolve user email')) {
      return 'No pudimos obtener tu correo de la sesión. Cierra sesión y vuelve a entrar.';
    }

    if (inner.contains('Failed to load expenses')) {
      return 'No se pudieron leer los egresos en el servidor. Sincroniza desde el inicio e inténtalo de nuevo.';
    }

    // 401 genérico: suele ser JWT rechazado por la gateway (p. ej. anon key) o proyecto distinto.
    if (inner.contains('Missing Authorization')) {
      return 'Falta autorización en la petición. Cierra sesión y entra de nuevo.';
    }
    if (lower.contains('401') || lower.contains('invalid jwt')) {
      return 'El servidor rechazó el acceso a la función (401). Si usas la clave publicable '
          'sb_publishable_…, la verificación JWT del proxy de Edge Functions no es compatible: '
          'despliega send-expense-export con verify_jwt desactivado (ver supabase/config.toml) '
          'o habilita de nuevo la clave anon legacy en Supabase → Settings → API. '
          'No suele ser un proyecto distinto; revisa también que ejecutes la app con '
          '--dart-define-from-file=dart_defines.json.';
    }

    if (inner.contains('Failed to send email') ||
        (lower.contains('resend') &&
            (lower.contains('reject') ||
                lower.contains('invalid') ||
                lower.contains('domain') ||
                lower.contains('verify')))) {
      if (lower.contains('only send testing emails') ||
          lower.contains('solo puede enviar')) {
        return 'Resend está en modo prueba: solo puede enviar a direcciones permitidas hasta que '
            'verifiques un dominio en resend.com/domains y configures MAIL_FROM con una dirección '
            'de ese dominio.';
      }
      if (lower.contains('domain') && lower.contains('not verified')) {
        return 'El dominio del remitente (MAIL_FROM) no está verificado en Resend. Agrega el dominio '
            'en resend.com/domains, configura DNS y usa MAIL_FROM con ese dominio.';
      }
      if (lower.contains('from') &&
          (lower.contains('invalid') ||
              lower.contains('not allowed') ||
              lower.contains('verify'))) {
        return 'Resend no acepta el remitente: verifica en resend.com/domains el dominio exacto del '
            'correo (p. ej. projects.yesidhernandez.dev si envías desde contact@projects...). '
            'El secreto en Supabase debe llamarse MAIL_FROM (sin comillas extra).';
      }
      final short = inner.length > 220 ? '${inner.substring(0, 220)}…' : inner;
      return 'El servicio de correo (Resend) rechazó el envío. Revisa RESEND_API_KEY, MAIL_FROM y '
            'los logs en resend.com (dominio verificado o modo prueba). Detalle: $short';
    }

    if (inner.contains('FunctionException') &&
        (raw.contains('404') || inner.contains('not found'))) {
      return 'No se encontró la función send-expense-export en este proyecto. Despliégala en Supabase.';
    }

    // Mostrar mensaje corto del servidor si es legible (ya va en español en muchos casos).
    if (inner.length <= 200 && !inner.contains('\n') && !inner.startsWith('FunctionException')) {
      return inner;
    }

    return expenseExportEmailFailed;
  }

  /// Sin egresos que exportar en el periodo seleccionado.
  static const String expenseExportNoRows = 'No hay egresos en este periodo para exportar.';

  /// Mensaje cuando falla cargar deudas.
  static const String debtsLoadFailed = 'No se pudieron cargar las deudas. Desliza hacia abajo para reintentar.';

  /// Mensaje cuando falla cargar el dashboard.
  static const String dashboardLoadFailed = 'No se pudo cargar el resumen. Desliza hacia abajo para reintentar.';

  /// Mensaje cuando falla cargar tarjetas.
  static const String cardsLoadFailed = 'No se pudieron cargar las tarjetas. Desliza hacia abajo para reintentar.';

  /// Mensaje cuando falla cargar medios de pago/ahorros.
  static const String savingsLoadFailed = 'No se pudieron cargar las cuentas de ahorro. Desliza hacia abajo para reintentar.';

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
