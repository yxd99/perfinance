// Layout común de los correos de Perfinance, con la identidad "Billete" de la
// app (DESIGN.md): papel crema, tinta, un solo morado y el monto como la
// denominación del billete. Hecho para clientes de correo: tablas, estilos en
// línea, colores sólidos (sin degradados ni sombras) y versión en texto plano.

export const EMAIL_COLORS = {
  page: "#F4EFE3",
  paper: "#FBF8F1",
  hairline: "#DCD3C1",
  ink: "#1E1B18",
  muted: "#5E574C",
  purple: "#5B3A7A",
  onPurple: "#FFFFFF",
  onPurpleMuted: "#E9DDF5",
} as const;

const FONT = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";

export type EmailRow = { label: string; value: string; strong?: boolean };

export type EmailContent = {
  /** <title> del documento. */
  title: string;
  /** Texto que la bandeja muestra junto al asunto. */
  preheader: string;
  /** Franja morada: etiqueta, monto y sello opcional ("Saldada"). */
  note: { label: string; amount: string; stamp?: string };
  heading: string;
  /** Párrafos en texto plano; se escapan. */
  intro: string[];
  rows: EmailRow[];
  /** Párrafos del pie en texto plano; se escapan. */
  footer: string[];
};

export function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

const copCurrency = new Intl.NumberFormat("es-CO", {
  style: "currency",
  currency: "COP",
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

/** "$ 400.000". Intl separa con espacio duro; se normaliza a espacio común para el texto plano. */
export function formatCop(n: number): string {
  return copCurrency.format(n).replace(/ /g, " ");
}

const MONTHS_ES = [
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
];

/** "20 de noviembre de 2026" a partir de una fecha ISO (día en UTC, como la guarda la app). */
export function formatDateEs(iso: string): string {
  const d = new Date(iso);
  return `${d.getUTCDate()} de ${MONTHS_ES[d.getUTCMonth()]} de ${d.getUTCFullYear()}`;
}

function rowHtml(row: EmailRow, first: boolean): string {
  const border = first ? "" : `border-top:1px solid ${EMAIL_COLORS.hairline};`;
  const weight = row.strong ? "700" : "400";
  return `<tr>
<td style="${border}padding:12px 0;font-family:${FONT};font-size:14px;line-height:20px;color:${EMAIL_COLORS.muted};">${escapeHtml(row.label)}</td>
<td align="right" style="${border}padding:12px 0 12px 16px;font-family:${FONT};font-size:15px;line-height:20px;color:${EMAIL_COLORS.ink};font-weight:${weight};font-variant-numeric:tabular-nums;">${escapeHtml(row.value)}</td>
</tr>`;
}

function paragraphs(items: string[], style: string): string {
  return items.map((p) => `<p style="margin:0 0 12px;${style}">${escapeHtml(p)}</p>`).join("\n");
}

export function renderEmail(c: EmailContent): string {
  const C = EMAIL_COLORS;
  const stamp = c.note.stamp
    ? `<td align="right" valign="top" style="padding:0;"><span style="display:inline-block;border:2px solid ${C.onPurple};border-radius:4px;padding:4px 10px;font-family:${FONT};font-size:12px;line-height:16px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:${C.onPurple};">${escapeHtml(c.note.stamp)}</span></td>`
    : "";
  const rows = c.rows.length === 0 ? "" : `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;margin:8px 0 4px;">
${c.rows.map((r, i) => rowHtml(r, i === 0)).join("\n")}
</table>`;

  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light only">
<meta name="supported-color-schemes" content="light">
<title>${escapeHtml(c.title)}</title>
</head>
<body style="margin:0;padding:0;background-color:${C.page};">
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:${C.page};">${escapeHtml(c.preheader)}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="${C.page}" style="background-color:${C.page};">
<tr><td align="center" style="padding:24px 12px;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;">
<tr><td style="padding:0 4px 12px;font-family:${FONT};font-size:14px;line-height:20px;font-weight:600;color:${C.ink};">Perfinance</td></tr>
<tr><td bgcolor="${C.paper}" style="background-color:${C.paper};border:1px solid ${C.hairline};border-radius:14px;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0">
<tr><td bgcolor="${C.purple}" style="background-color:${C.purple};border-radius:13px 13px 0 0;padding:24px;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr>
<td valign="top" style="padding:0;">
<p style="margin:0 0 6px;font-family:${FONT};font-size:14px;line-height:20px;color:${C.onPurpleMuted};">${escapeHtml(c.note.label)}</p>
<p style="margin:0;font-family:${FONT};font-size:34px;line-height:40px;font-weight:800;color:${C.onPurple};font-variant-numeric:tabular-nums;">${escapeHtml(c.note.amount)}</p>
</td>
${stamp}
</tr></table>
</td></tr>
<tr><td style="padding:24px 24px 8px;">
<h1 style="margin:0 0 12px;font-family:${FONT};font-size:20px;line-height:26px;font-weight:600;color:${C.ink};">${escapeHtml(c.heading)}</h1>
${paragraphs(c.intro, `font-family:${FONT};font-size:15px;line-height:22px;color:${C.ink};`)}
${rows}
</td></tr>
<tr><td style="padding:16px 24px 24px;border-top:1px solid ${C.hairline};">
${paragraphs(c.footer, `font-family:${FONT};font-size:13px;line-height:19px;color:${C.muted};`)}
</td></tr>
</table>
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>`;
}

/** Versión en texto plano del mismo contenido (mejora la entrega y la lectura sin HTML). */
export function renderPlainText(c: EmailContent): string {
  const lines = [
    `${c.note.label}: ${c.note.amount}${c.note.stamp ? ` (${c.note.stamp})` : ""}`,
    "",
    c.heading,
    "",
    ...c.intro.flatMap((p) => [p, ""]),
    ...c.rows.map((r) => `${r.label}: ${r.value}`),
    "",
    "--",
    ...c.footer.flatMap((p) => [p, ""]),
  ];
  return lines.join("\n").replace(/\n{3,}/g, "\n\n").trim() + "\n";
}

/**
 * Cambia el nombre visible del remitente conservando la dirección de MAIL_FROM.
 * "Perfinance <hola@dominio>" + "Ana vía Perfinance" -> "Ana vía Perfinance <hola@dominio>".
 */
export function fromWithDisplayName(mailFrom: string, displayName: string): string {
  const match = mailFrom.match(/<([^>]+)>/);
  const address = (match ? match[1] : mailFrom).trim();
  // Sin saltos de línea (evita inyectar cabeceras) ni caracteres que rompan la dirección.
  const name = displayName.replace(/[\r\n]+/g, " ").replace(/[<>"\\]/g, "").replace(/\s+/g, " ").trim().slice(0, 60);
  return name ? `${name} <${address}>` : address;
}
