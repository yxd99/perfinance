// Validación del destinatario. Debe coincidir con isValidEmail en
// lib/core/utils/email.dart (la app valida lo mismo antes de enviar).

const EMAIL_PATTERN = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$/;

/** Forma con la que se guarda y compara el correo en email_recipient_allowlist. */
export function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

export function isValidEmail(value: string): boolean {
  const email = value.trim();
  return email.length <= 254 && EMAIL_PATTERN.test(email);
}
