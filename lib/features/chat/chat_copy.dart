/// Mensaje para mostrar cuando el asesor no pudo responder. El texto crudo
/// (códigos HTTP, cuerpos de error) queda en el estado y en Sentry, no en pantalla.
String chatErrorMessage(String? raw) {
  final msg = (raw ?? '').toLowerCase();
  if (msg.contains('sesión') || msg.contains('session') || msg.contains('401') || msg.contains('jwt')) {
    return 'Tu sesión venció. Cierra sesión y vuelve a entrar para seguir.';
  }
  if (msg.contains('socket') || msg.contains('network') || msg.contains('connection') || msg.contains('timeout')) {
    return 'Sin conexión. El asesor necesita internet; revisa la red e intenta de nuevo.';
  }
  return 'No se pudo obtener respuesta. Intenta de nuevo.';
}
