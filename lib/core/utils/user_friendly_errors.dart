/// Convierte excepciones técnicas en mensajes amigables para el usuario.
class UserFriendlyErrors {
  UserFriendlyErrors._();

  /// Mensaje genérico cuando algo falla al cargar.
  static const String loadFailed = 'No se pudo cargar. Revisá tu conexión e intentá de nuevo.';

  /// Mensaje cuando falla la sincronización.
  static const String syncFailed = 'No se pudo sincronizar. Comprobá tu conexión y volvé a intentarlo.';

  /// Mensaje cuando falla el inicio de sesión.
  static const String loginFailed = 'No pudimos iniciar sesión. Revisá tu correo y contraseña.';

  /// Mensaje cuando falla el registro.
  static const String registerFailed = 'No pudimos crear tu cuenta. Intentalo de nuevo más tarde.';

  /// Mensaje cuando falla cargar egresos.
  static const String expensesLoadFailed = 'No se pudieron cargar los egresos. Deslizá hacia abajo para reintentar.';

  /// Mensaje cuando falla enviar el export de egresos por correo.
  static const String expenseExportEmailFailed =
      'No se pudo enviar el correo con el archivo. Comprobá tu conexión e intentalo de nuevo.';

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
      return 'La petición tardó demasiado o quedó bloqueada. Comprobá la conexión e intentalo de nuevo.';
    }

    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('socket') ||
        lower.contains('failed host lookup') ||
        lower.contains('timed out')) {
      return 'Sin conexión. Comprobá tu internet e intentalo de nuevo.';
    }

    if (inner.contains('Email not configured on server')) {
      return 'Falta configurar el correo en el servidor: en Supabase → Edge Functions → '
          'Secrets, definí RESEND_API_KEY y MAIL_FROM (remitente verificado en Resend).';
    }

    if (inner.contains('NO_USER_SESSION')) {
      return 'No hay sesión activa para llamar al servidor. Cerrá la app o volvé a iniciar sesión e intentalo de nuevo.';
    }

    if (inner.contains('SESSION_REFRESH_FAILED')) {
      return 'La sesión caducó o no se pudo renovar. Volvé a iniciar sesión en la app e intentalo de nuevo.';
    }

    if (inner.contains('Unable to resolve user email')) {
      return 'No pudimos obtener tu correo de la sesión. Cerrá sesión y volvé a entrar.';
    }

    if (inner.contains('Failed to load expenses')) {
      return 'No se pudieron leer los egresos en el servidor. Sincronizá desde el inicio e intentalo de nuevo.';
    }

    // 401 genérico: suele ser JWT rechazado por la gateway (p. ej. anon key) o proyecto distinto.
    if (inner.contains('Missing Authorization')) {
      return 'Falta autorización en la petición. Cerrá sesión y entrá de nuevo.';
    }
    if (lower.contains('401') || lower.contains('invalid jwt')) {
      return 'El servidor rechazó el acceso a la función (401). Si usás la clave publicable '
          'sb_publishable_…, la verificación JWT del proxy de Edge Functions no es compatible: '
          'desplegá send-expense-export con verify_jwt desactivado (ver supabase/config.toml) '
          'o habilitá de nuevo la clave anon legacy en Supabase → Settings → API. '
          'No suele ser un proyecto distinto; revisá también que ejecutes la app con '
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
        return 'El dominio del remitente (MAIL_FROM) no está verificado en Resend. Agregá el dominio '
            'en resend.com/domains, configurá DNS y usá MAIL_FROM con ese dominio.';
      }
      if (lower.contains('from') &&
          (lower.contains('invalid') ||
              lower.contains('not allowed') ||
              lower.contains('verify'))) {
        return 'Resend no acepta el remitente: verificá en resend.com/domains el dominio exacto del '
            'correo (p. ej. projects.yesidhernandez.dev si enviás desde contact@projects...). '
            'El secreto en Supabase debe llamarse MAIL_FROM (sin comillas extra).';
      }
      final short = inner.length > 220 ? '${inner.substring(0, 220)}…' : inner;
      return 'El servicio de correo (Resend) rechazó el envío. Revisá RESEND_API_KEY, MAIL_FROM y '
            'los logs en resend.com (dominio verificado o modo prueba). Detalle: $short';
    }

    if (inner.contains('FunctionException') &&
        (raw.contains('404') || inner.contains('not found'))) {
      return 'No se encontró la función send-expense-export en este proyecto. Desplegala en Supabase.';
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
  static const String debtsLoadFailed = 'No se pudieron cargar las deudas. Deslizá hacia abajo para reintentar.';

  /// Mensaje cuando falla cargar el dashboard.
  static const String dashboardLoadFailed = 'No se pudo cargar el resumen. Deslizá hacia abajo para reintentar.';

  /// Mensaje cuando falla cargar tarjetas.
  static const String cardsLoadFailed = 'No se pudieron cargar las tarjetas. Deslizá hacia abajo para reintentar.';

  /// Mensaje cuando falla cargar medios de pago/ahorros.
  static const String savingsLoadFailed = 'No se pudieron cargar los medios de pago. Deslizá hacia abajo para reintentar.';

  /// Convierte un error de auth (Exception o mensaje de Supabase) en texto amigable.
  static String authMessage(Object? error, {required bool isLogin}) {
    if (error == null) return isLogin ? loginFailed : registerFailed;
    final msg = error.toString().toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid_credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (msg.contains('email') && msg.contains('confirm')) {
      return 'Revisá tu correo y confirmá tu cuenta antes de iniciar sesión.';
    }
    if (msg.contains('network') || msg.contains('connection') || msg.contains('socket')) {
      return 'Sin conexión. Revisá tu internet e intentá de nuevo.';
    }
    if (msg.contains('user already registered') || msg.contains('already registered')) {
      return 'Ya existe una cuenta con este correo. Iniciá sesión o usá otro correo.';
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
      return 'Sin conexión. Comprobá tu internet e intentá de nuevo.';
    }
    if (msg.contains('database') || msg.contains('sql')) {
      return 'Hubo un problema con los datos. Cerrá la app y abrila de nuevo.';
    }
    return fallback;
  }
}
