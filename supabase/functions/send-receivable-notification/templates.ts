// Correos que recibe el deudor cuando alguien registra o cambia una deuda a su
// nombre. Quien los lee muchas veces no usa Perfinance: por eso nombran a quien
// cobra, usan las palabras del deudor ("tu pago", no "cobro") y explican qué es
// la app y qué hacer si no reconoce la deuda.
import { type EmailContent, type EmailRow, formatCop, formatDateEs, renderEmail, renderPlainText } from "../_shared/email_layout.ts";

export type NotificationEvent =
  | "created"
  | "payment_recorded"
  | "payment_edited"
  | "payment_deleted"
  | "reminder";

export type NotificationInput = {
  event: NotificationEvent;
  debtorName: string;
  description?: string;
  totalAmount: number;
  remainingBalance: number;
  paymentAmount?: number;
  paymentDate?: string;
  /** Nombre de quien cobra (Tu cuenta › Nombre). Sin nombre se usa su correo. */
  creditorName?: string | null;
  /** Correo de quien cobra: va en el pie y es la dirección de respuesta. */
  creditorEmail: string;
  /** El deudor también usa Perfinance y ve la deuda en su app. */
  isRegistered?: boolean;
};

export type NotificationEmail = { subject: string; html: string; text: string; fromName: string };

export function buildNotificationEmail(input: NotificationInput): NotificationEmail {
  const creditor = input.creditorName?.trim() || input.creditorEmail;
  const debtor = input.debtorName.trim();
  const remaining = formatCop(Math.max(0, input.remainingBalance));
  const total = formatCop(input.totalAmount);
  const payment = input.paymentAmount != null ? formatCop(input.paymentAmount) : null;
  const paymentDate = input.paymentDate ? formatDateEs(input.paymentDate) : null;
  const settled = input.remainingBalance <= 0 && input.event !== "payment_deleted";

  const rows: EmailRow[] = [];
  const description = input.description?.trim();
  if (description) rows.push({ label: "Concepto", value: description });
  rows.push({ label: "Deuda total", value: total, strong: true });

  let subject: string;
  let heading: string;
  let intro: string;
  let note: EmailContent["note"] = { label: "Te falta por pagar", amount: remaining };

  switch (input.event) {
    case "created":
      subject = `${creditor} registró una deuda contigo`;
      heading = subject;
      intro = `Hola, ${debtor}. ${creditor} anotó en Perfinance que le debes ${total}.`;
      note = { label: `Le debes a ${creditor}`, amount: remaining };
      break;
    case "payment_recorded":
      if (payment) rows.push({ label: settled ? "Último pago" : "Pago", value: payment, strong: true });
      if (paymentDate) rows.push({ label: "Fecha del pago", value: paymentDate });
      if (settled) {
        subject = `Saldaste tu deuda con ${creditor}`;
        heading = "Deuda saldada";
        intro = `Hola, ${debtor}. ${creditor} registró tu último pago. Ya no le debes nada.`;
        note = { label: `Pagaste a ${creditor}`, amount: total, stamp: "Saldada" };
      } else {
        subject = `${creditor} registró tu pago de ${payment ?? ""}`.trim();
        heading = `${creditor} registró tu pago`;
        intro = `Hola, ${debtor}. ${creditor} anotó un pago tuyo${payment ? ` de ${payment}` : ""}.`;
      }
      break;
    case "payment_edited":
      if (payment) rows.push({ label: "Pago", value: payment, strong: true });
      if (paymentDate) rows.push({ label: "Fecha del pago", value: paymentDate });
      subject = `${creditor} corrigió un pago tuyo`;
      heading = subject;
      intro = `Hola, ${debtor}. ${creditor} corrigió el valor o la fecha de un pago tuyo. Así queda tu deuda.`;
      if (settled) note = { label: `Pagaste a ${creditor}`, amount: total, stamp: "Saldada" };
      break;
    case "payment_deleted":
      if (payment) rows.push({ label: "Pago eliminado", value: payment, strong: true });
      if (paymentDate) rows.push({ label: "Fecha del pago", value: paymentDate });
      subject = `${creditor} eliminó un pago de tu deuda`;
      heading = subject;
      intro = `Hola, ${debtor}. ${creditor} eliminó un pago que había anotado. Ese valor vuelve a tu saldo.`;
      break;
    case "reminder":
      subject = `Recordatorio de ${creditor}: tienes un saldo pendiente`;
      heading = "Tienes un saldo pendiente";
      intro = `Hola, ${debtor}. ${creditor} te recuerda que todavía le debes ${remaining}.`;
      break;
  }

  const introParagraphs = [intro];
  if (input.isRegistered) {
    introParagraphs.push("También puedes verla en tu app de Perfinance, en la sección Deudas.");
  }

  const content: EmailContent = {
    title: subject,
    preheader: `${note.label}: ${note.amount}`,
    note,
    heading,
    intro: introParagraphs,
    rows,
    footer: [
      `Recibes este correo porque ${creditor} (${input.creditorEmail}) registró esta deuda a tu nombre en Perfinance, una app para llevar las cuentas personales.`,
      `Si no reconoces esta deuda o tienes preguntas, responde este correo: la respuesta le llega a ${creditor}.`,
      `Si no quieres recibir más avisos, pídele a ${creditor} que quite tu correo de la deuda.`,
    ],
  };

  return {
    subject,
    html: renderEmail(content),
    text: renderPlainText(content),
    fromName: `${creditor} vía Perfinance`,
  };
}
