/// Formato de correo aceptado por la app. Debe coincidir con `isValidEmail` en
/// `supabase/functions/send-receivable-notification/recipient.ts`.
final _emailPattern = RegExp(
  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$',
);

/// Devuelve true si [value] (sin espacios a los lados) tiene formato de correo.
bool isValidEmail(String value) {
  final email = value.trim();
  return email.length <= 254 && _emailPattern.hasMatch(email);
}
