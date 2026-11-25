import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Datos de la cuenta que se muestran en Más › Tu cuenta. El nombre vive en los
/// metadatos de Supabase Auth (`full_name`), no en una tabla.
class AccountInfo {
  const AccountInfo({required this.email, required this.name});

  factory AccountInfo.fromMetadata({required String email, required Map<String, dynamic>? metadata}) {
    final name = metadata?['full_name'];
    return AccountInfo(email: email, name: name is String ? name : null);
  }

  final String email;
  final String? name;

  /// El nombre si lo tiene; si no, el correo.
  String get displayName {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? email : trimmed;
  }
}

/// La contraseña actual que escribió el usuario no es la de su cuenta.
class WrongCurrentPasswordException implements Exception {
  const WrongCurrentPasswordException();
}

/// Valida el formulario de cambio de contraseña. Devuelve el mensaje para el
/// usuario, o null si todo está bien.
String? validateNewPassword({required String current, required String next, required String confirm}) {
  if (current.isEmpty) return 'Escribe tu contraseña actual.';
  if (next.length < 8) return 'La contraseña nueva debe tener al menos 8 caracteres.';
  if (next != confirm) return 'Las contraseñas nuevas no coinciden.';
  if (next == current) return 'La contraseña nueva debe ser distinta de la actual.';
  return null;
}

abstract class AccountService {
  Future<void> updateName(String name);

  /// Lanza [WrongCurrentPasswordException] si [current] no es la contraseña de la cuenta.
  Future<void> changePassword({required String current, required String next});
}

class SupabaseAccountService implements AccountService {
  SupabaseAccountService(this._client);

  final SupabaseClient _client;

  @override
  Future<void> updateName(String name) async {
    await _client.auth.updateUser(UserAttributes(data: {'full_name': name}));
  }

  @override
  Future<void> changePassword({required String current, required String next}) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw StateError('NO_USER_SESSION');
    // Supabase no pide la contraseña actual para cambiarla: se verifica
    // iniciando sesión con ella, para que un teléfono desbloqueado no baste.
    try {
      await _client.auth.signInWithPassword(email: email, password: current);
    } on AuthException catch (e) {
      // Solo credenciales inválidas son "contraseña incorrecta"; otro 400 (por
      // ejemplo correo sin confirmar) sigue como error. Sin código = gotrue viejo.
      if (e.code == 'invalid_credentials' || (e.code == null && e.statusCode == '400')) {
        throw const WrongCurrentPasswordException();
      }
      rethrow;
    }
    await _client.auth.updateUser(UserAttributes(password: next));
  }
}

final accountServiceProvider = Provider<AccountService>(
  (ref) => SupabaseAccountService(Supabase.instance.client),
);

/// Se invalida después de guardar el nombre para releer el usuario actual.
final accountInfoProvider = Provider<AccountInfo>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  return AccountInfo.fromMetadata(email: user?.email ?? '', metadata: user?.userMetadata);
});
