import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/features/auth/account_service.dart';

void main() {
  group('validateNewPassword', () {
    test('acepta una contraseña nueva válida', () {
      expect(validateNewPassword(current: 'vieja1234', next: 'nueva1234', confirm: 'nueva1234'), isNull);
    });

    test('pide al menos 8 caracteres', () {
      expect(
        validateNewPassword(current: 'vieja1234', next: 'corta', confirm: 'corta'),
        'La contraseña nueva debe tener al menos 8 caracteres.',
      );
    });

    test('la confirmación debe coincidir', () {
      expect(
        validateNewPassword(current: 'vieja1234', next: 'nueva1234', confirm: 'nueva12345'),
        'Las contraseñas nuevas no coinciden.',
      );
    });

    test('la nueva debe ser distinta de la actual', () {
      expect(
        validateNewPassword(current: 'misma1234', next: 'misma1234', confirm: 'misma1234'),
        'La contraseña nueva debe ser distinta de la actual.',
      );
    });

    test('pide la contraseña actual', () {
      expect(
        validateNewPassword(current: '', next: 'nueva1234', confirm: 'nueva1234'),
        'Escribe tu contraseña actual.',
      );
    });
  });

  group('AccountInfo', () {
    test('displayName usa el nombre y si no hay, el correo', () {
      expect(const AccountInfo(email: 'ana@gmail.com', name: 'Ana').displayName, 'Ana');
      expect(const AccountInfo(email: 'ana@gmail.com', name: null).displayName, 'ana@gmail.com');
      expect(const AccountInfo(email: 'ana@gmail.com', name: '  ').displayName, 'ana@gmail.com');
    });

    test('fromMetadata lee full_name', () {
      final info = AccountInfo.fromMetadata(email: 'ana@gmail.com', metadata: {'full_name': 'Ana Pérez'});
      expect(info.name, 'Ana Pérez');
      expect(AccountInfo.fromMetadata(email: 'a@b.co', metadata: null).name, isNull);
    });
  });
}
