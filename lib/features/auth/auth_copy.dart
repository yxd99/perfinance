/// Textos de inicio de sesión y registro, con voseo.
abstract class AuthCopy {
  static const loginFailed = 'No pudimos iniciar sesión. Revisá tu correo y contraseña.';
  static const registerFailed = 'No pudimos crear tu cuenta. Intentá de nuevo en un rato.';
  static const emailRequired = 'Escribí tu correo';
  static const emailInvalid = 'Ese correo no parece válido';
  static const passwordRequired = 'Escribí tu contraseña';
  static const newPasswordRequired = 'Elegí una contraseña';
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
      return 'Confirmá tu cuenta desde el correo que te enviamos y volvé a intentar.';
    }
    if (msg.contains('network') || msg.contains('connection') || msg.contains('socket')) {
      return 'Sin conexión. Revisá tu internet e intentá de nuevo.';
    }
    if (msg.contains('already registered')) {
      return 'Ya hay una cuenta con este correo. Iniciá sesión o usá otro correo.';
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
