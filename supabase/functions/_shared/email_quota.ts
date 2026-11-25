// Tope mensual de correos por cuenta (migración 020). Lo usan send-expense-export
// y send-receivable-notification con un cliente de service role.
import type { SupabaseClient } from "@supabase/supabase-js";

export type EmailKind = "expense_export" | "receivable_notification";

export type EmailClaim =
  | { allowed: true; logId: number; sentCount: number; quota: number }
  | { allowed: false; sentCount: number; quota: number };

/**
 * Reserva un envío para el usuario. Lanza si la base no respondió: quien llama
 * no debe enviar en ese caso.
 */
export async function claimEmailSend(
  admin: SupabaseClient,
  userId: string,
  kind: EmailKind,
  recipient: string,
): Promise<EmailClaim> {
  const { data, error } = await admin
    .rpc("claim_email_send", { p_user_id: userId, p_kind: kind, p_recipient: recipient })
    .single();
  if (error || !data) throw new Error(`claim_email_send failed: ${error?.message ?? "no data"}`);
  const row = data as { allowed: boolean; sent_count: number; quota: number; log_id: number | null };
  if (row.allowed && row.log_id != null) {
    return { allowed: true, logId: row.log_id, sentCount: row.sent_count, quota: row.quota };
  }
  return { allowed: false, sentCount: row.sent_count, quota: row.quota };
}

/** Devuelve el cupo de un envío que no salió (por ejemplo, Resend falló). */
export async function releaseEmailSend(admin: SupabaseClient, logId: number): Promise<void> {
  const { error } = await admin.from("email_send_log").delete().eq("id", logId);
  if (error) console.error("[email_quota] release failed", logId, error);
}

const MONTHS_ES = [
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
];

/** Mensaje para el usuario cuando llegó al tope. El mes se calcula en hora de Colombia. */
export function quotaExceededMessage(quota: number, now: Date = new Date()): string {
  const bogotaMonth = Number(
    new Intl.DateTimeFormat("en-US", { timeZone: "America/Bogota", month: "numeric" }).format(now),
  );
  const nextMonth = MONTHS_ES[bogotaMonth % 12];
  const noun = quota === 1 ? "correo" : "correos";
  return `Llegaste al límite de ${quota} ${noun} de este mes. Podrás enviar más desde el 1 de ${nextMonth}.`;
}
