import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/features/chat/chat_copy.dart';

void main() {
  test('sesión vencida', () {
    expect(chatErrorMessage('No hay sesión activa'), contains('sesión venció'));
    expect(chatErrorMessage('Error 401: {"msg":"Invalid JWT"}'), contains('sesión venció'));
  });

  test('sin conexión', () {
    expect(chatErrorMessage('SocketException: Failed host lookup'), startsWith('Sin conexión'));
  });

  test('cualquier otro error nunca muestra el texto crudo', () {
    final msg = chatErrorMessage('Error 500: {"error":"boom"}');
    expect(msg, 'No se pudo obtener respuesta. Intenta de nuevo.');
    expect(chatErrorMessage(null), 'No se pudo obtener respuesta. Intenta de nuevo.');
  });
}
