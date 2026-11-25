// Correo con el Excel de egresos que el usuario pide desde la app.
import { type EmailContent, formatCop, renderEmail, renderPlainText } from "../_shared/email_layout.ts";

export type ExportEmailInput = { periodLabel: string; rowCount: number; total: number };

export function buildExportEmail(input: ExportEmailInput): { html: string; text: string } {
  const total = formatCop(input.total);
  const count = `${input.rowCount} ${input.rowCount === 1 ? "egreso" : "egresos"}`;
  const content: EmailContent = {
    title: `Tus egresos de ${input.periodLabel}`,
    preheader: `${count} por ${total} en ${input.periodLabel}. El Excel va adjunto.`,
    note: { label: `Gastaste en ${input.periodLabel}`, amount: total },
    heading: `Tus egresos de ${input.periodLabel}`,
    intro: [
      `Te enviamos el archivo de Excel con ${count}: el detalle de cada uno y los totales por tarjeta y cuenta.`,
    ],
    rows: [
      { label: "Periodo", value: input.periodLabel },
      { label: "Egresos", value: String(input.rowCount) },
    ],
    footer: ["Pediste esta exportación desde la app de Perfinance. Si no fuiste tú, cambia tu contraseña en Más › Tu cuenta."],
  };
  return { html: renderEmail(content), text: renderPlainText(content) };
}
