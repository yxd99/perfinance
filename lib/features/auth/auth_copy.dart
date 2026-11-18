/// Textos de inicio de sesión y registro, en español colombiano neutro (tú).
abstract class AuthCopy {
  static const loginFailed = 'No pudimos iniciar sesión. Revisa tu correo y contraseña.';
  static const registerFailed = 'No pudimos crear tu cuenta. Intenta de nuevo en un rato.';
  static const emailRequired = 'Escribe tu correo';
  static const emailInvalid = 'Ese correo no parece válido';
  static const passwordRequired = 'Escribe tu contraseña';
  static const newPasswordRequired = 'Elige una contraseña';
  static const passwordTooShort = 'Tiene que tener al menos 6 caracteres';
  static const passwordMismatch = 'Las contraseñas no coinciden';

  /// Traduce un error de Supabase Auth a un mensaje que dice qué pasó y qué hacer.
  static String errorMessage(Object? error, {required bool isLogin}) {
    final fallback = isLogin ? loginFailed : registerFailed;
    if (error == null) return fallback;
    final msg = error.toString().toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid_credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (msg.contains('email') && msg.contains('confirm')) {
      return 'Confirma tu cuenta desde el correo que te enviamos y vuelve a intentar.';
    }
    if (msg.contains('network') || msg.contains('connection') || msg.contains('socket')) {
      return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
    }
    if (msg.contains('already registered')) {
      return 'Ya hay una cuenta con este correo. Inicia sesión o usa otro correo.';
    }
    if (msg.contains('password') || msg.contains('weak')) {
      return 'La contraseña tiene que tener al menos 6 caracteres.';
    }
    return fallback;
  }

  static String? validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return emailRequired;
    if (!value.contains('@') || !value.contains('.')) return emailInvalid;
    return null;
  }
}
