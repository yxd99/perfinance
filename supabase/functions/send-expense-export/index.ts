import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { encodeBase64 } from "jsr:@std/encoding@1/base64";
import { createClient } from "@supabase/supabase-js";
import XLSX from "xlsx-js-style";
import { claimEmailSend, type EmailClaim, quotaExceededMessage, releaseEmailSend } from "../_shared/email_quota.ts";

type Body = {
  rangeLabel?: string;
  windowStartIso?: string;
  windowEndIso?: string;
  /** Igual que `DateTime.now().timeZoneOffset.inMinutes` en Flutter para fechas `dd/MM/yyyy`. */
  timezoneOffsetMinutes?: number;
  /** Correo desde el cliente (sesión); fallback cuando el JWT no trae `email`. */
  recipientEmail?: string;
};

type ExpenseRow = {
  id: string;
  amount: number;
  date: string;
  payment_type: string;
  payment_ref: string;
  description: string | null;
};

type CardRow = { id: string; alias: string };
type MethodRow = { id: string; name: string };

const MONTH_NAMES_ES = [
  "",
  "enero",
  "febrero",
  "marzo",
  "abril",
  "mayo",
  "junio",
  "julio",
  "agosto",
  "septiembre",
  "octubre",
  "noviembre",
  "diciembre",
];

const copCurrency = new Intl.NumberFormat("es-CO", {
  style: "currency",
  currency: "COP",
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

/** Monto en COP para Excel y correo (p. ej. `$ 1.234.567`). */
function formatCopAmount(n: number): string {
  return copCurrency.format(n);
}

function capitalizeEs(s: string): string {
  if (!s) return s;
  return s.charAt(0).toLocaleUpperCase("es") + s.slice(1);
}

function daysInMonth(y: number, m: number): number {
  return new Date(y, m, 0).getDate();
}

/** Partes de calendario en la zona horaria del cliente (`offsetMinutes` como en Flutter). */
function localCalendarParts(
  isoDate: string,
  offsetMinutes: number,
): { y: number; m: number; d: number } {
  const instant = Date.parse(isoDate);
  const shifted = instant + offsetMinutes * 60 * 1000;
  const u = new Date(shifted);
  return {
    y: u.getUTCFullYear(),
    m: u.getUTCMonth() + 1,
    d: u.getUTCDate(),
  };
}

function nowLocalCalendarParts(offsetMinutes: number): {
  y: number;
  m: number;
  d: number;
} {
  const shifted = Date.now() + offsetMinutes * 60 * 1000;
  const u = new Date(shifted);
  return {
    y: u.getUTCFullYear(),
    m: u.getUTCMonth() + 1,
    d: u.getUTCDate(),
  };
}

/**
 * Texto del periodo para el asunto del correo y el nombre del archivo:
 * - Mes en curso hasta hoy → "Mayo (actual)"
 * - Varios meses mismo año → "Mayo-Junio 2026"
 * - Un solo día → "18 de abril de 2026"
 */
function subjectPeriodDescription(
  windowStartIso: string,
  windowEndIso: string,
  offsetMinutes: number,
): string {
  const start = localCalendarParts(windowStartIso, offsetMinutes);
  const end = localCalendarParts(windowEndIso, offsetMinutes);
  const now = nowLocalCalendarParts(offsetMinutes);

  const sameDay =
    start.y === end.y && start.m === end.m && start.d === end.d;

  if (sameDay) {
    return `${start.d} de ${MONTH_NAMES_ES[start.m]} de ${start.y}`;
  }

  const sameMonthYear = start.y === end.y && start.m === end.m;

  if (sameMonthYear) {
    const isCurrentMonthTrailingToday =
      start.d === 1 &&
      start.y === now.y &&
      start.m === now.m &&
      end.y === now.y &&
      end.m === now.m &&
      end.d === now.d;

    if (isCurrentMonthTrailingToday) {
      return `${capitalizeEs(MONTH_NAMES_ES[start.m])} (actual)`;
    }

    const last = daysInMonth(end.y, end.m);
    if (start.d === 1 && end.d === last) {
      return `${capitalizeEs(MONTH_NAMES_ES[start.m])} ${start.y}`;
    }

    return `${capitalizeEs(MONTH_NAMES_ES[start.m])} ${start.y} (${start.d}-${end.d})`;
  }

  if (start.y === end.y) {
    return `${capitalizeEs(MONTH_NAMES_ES[start.m])}-${
      capitalizeEs(MONTH_NAMES_ES[end.m])
    } ${start.y}`;
  }

  return `${capitalizeEs(MONTH_NAMES_ES[start.m])} ${start.y}-${
    capitalizeEs(MONTH_NAMES_ES[end.m])
  } ${end.y}`;
}

/** Aproxima `DateTime.parse(iso).toLocal()` usando el offset enviado desde el cliente. */
function formatLocalDate(isoDate: string, offsetMinutes: number): string {
  const instant = Date.parse(isoDate);
  const shifted = instant + offsetMinutes * 60 * 1000;
  const u = new Date(shifted);
  const dd = String(u.getUTCDate()).padStart(2, "0");
  const mm = String(u.getUTCMonth() + 1).padStart(2, "0");
  const yyyy = u.getUTCFullYear();
  return `${dd}/${mm}/${yyyy}`;
}

function aliasFor(
  e: ExpenseRow,
  cardMap: Map<string, string>,
  methodMap: Map<string, string>,
): string {
  if (e.payment_type === "credit_card") {
    return cardMap.get(e.payment_ref) ?? "Tarjeta";
  }
  return methodMap.get(e.payment_ref) ?? "Medio";
}

const thinBorder = {
  top: { style: "thin", color: { rgb: "CCCCCC" } },
  bottom: { style: "thin", color: { rgb: "CCCCCC" } },
  left: { style: "thin", color: { rgb: "CCCCCC" } },
  right: { style: "thin", color: { rgb: "CCCCCC" } },
};

type StyledCell = { s?: Record<string, unknown> };
type MutableSheet = Record<string, unknown>;

function setCellStyle(addr: string, ws: MutableSheet, style: Record<string, unknown>) {
  const cell = ws[addr] as StyledCell | undefined;
  if (!cell || typeof cell !== "object") return;
  cell.s = style;
}

/** Encabezado verde, filas alternadas, fila TOTAL resaltada. */
function applyDetailSheetPresentation(ws: MutableSheet, dataRowCount: number) {
  const cols = 4;
  const headerRow = 0;
  const totalRow = dataRowCount + 1;

  ws["!cols"] = [{ wch: 26 }, { wch: 12 }, { wch: 44 }, { wch: 18 }];
  ws["!rows"] = [{ hpt: 22 }];

  const headerStyle = {
    font: { bold: true, color: { rgb: "FFFFFF" } },
    fill: { patternType: "solid", fgColor: { rgb: "217346" } },
    alignment: { horizontal: "center", vertical: "center", wrapText: true },
    border: thinBorder,
  };

  for (let c = 0; c < cols; c++) {
    const addr = XLSX.utils.encode_cell({ r: headerRow, c });
    setCellStyle(addr, ws, headerStyle);
  }

  for (let r = 1; r <= dataRowCount; r++) {
    const fillRgb = r % 2 === 1 ? "FAFAFA" : "FFFFFF";
    const rowStyle = {
      alignment: {
        horizontal: "left",
        vertical: "center",
        wrapText: true,
      },
      fill: { patternType: "solid", fgColor: { rgb: fillRgb } },
      border: thinBorder,
    };
    const numStyle = {
      ...rowStyle,
      alignment: { horizontal: "right", vertical: "center", wrapText: true },
    };
    for (let c = 0; c < cols; c++) {
      const addr = XLSX.utils.encode_cell({ r, c });
      setCellStyle(addr, ws, c === cols - 1 ? numStyle : rowStyle);
    }
  }

  const totalFill = "E8F5E9";
  for (let c = 0; c < cols; c++) {
    const addr = XLSX.utils.encode_cell({ r: totalRow, c });
    const isAmountCol = c === cols - 1;
    setCellStyle(addr, ws, {
      font: { bold: true },
      fill: { patternType: "solid", fgColor: { rgb: totalFill } },
      alignment: isAmountCol
        ? { horizontal: "right", vertical: "center" }
        : { horizontal: "left", vertical: "center" },
      border: thinBorder,
    });
  }
}

/** Misma línea visual que Detalle (2 columnas). */
function applyTotalsSheetPresentation(ws: MutableSheet, labelRowCount: number) {
  const cols = 2;
  const headerRow = 0;
  const totalRow = labelRowCount + 1;

  ws["!cols"] = [{ wch: 30 }, { wch: 20 }];
  ws["!rows"] = [{ hpt: 22 }];

  const headerStyle = {
    font: { bold: true, color: { rgb: "FFFFFF" } },
    fill: { patternType: "solid", fgColor: { rgb: "217346" } },
    alignment: { horizontal: "center", vertical: "center", wrapText: true },
    border: thinBorder,
  };

  for (let c = 0; c < cols; c++) {
    const addr = XLSX.utils.encode_cell({ r: headerRow, c });
    setCellStyle(addr, ws, headerStyle);
  }

  for (let r = 1; r <= labelRowCount; r++) {
    const fillRgb = r % 2 === 1 ? "FAFAFA" : "FFFFFF";
    const left = {
      alignment: { horizontal: "left", vertical: "center", wrapText: true },
      fill: { patternType: "solid", fgColor: { rgb: fillRgb } },
      border: thinBorder,
    };
    const right = {
      alignment: { horizontal: "right", vertical: "center", wrapText: true },
      fill: { patternType: "solid", fgColor: { rgb: fillRgb } },
      border: thinBorder,
    };
    setCellStyle(XLSX.utils.encode_cell({ r, c: 0 }), ws, left);
    setCellStyle(XLSX.utils.encode_cell({ r, c: 1 }), ws, right);
  }

  const totalFill = "E8F5E9";
  for (let c = 0; c < cols; c++) {
    const addr = XLSX.utils.encode_cell({ r: totalRow, c });
    const isAmountCol = c === 1;
    setCellStyle(addr, ws, {
      font: { bold: true },
      fill: { patternType: "solid", fgColor: { rgb: totalFill } },
      alignment: isAmountCol
        ? { horizontal: "right", vertical: "center" }
        : { horizontal: "left", vertical: "center" },
      border: thinBorder,
    });
  }
}

/** Primera hoja: detalle; segunda hoja: totales por tarjeta; ambas con fila TOTAL al pie. */
function buildExpenseWorkbook(
  rows: ExpenseRow[],
  cardMap: Map<string, string>,
  methodMap: Map<string, string>,
  offsetMinutes: number,
): Uint8Array {
  const detailHeader: [string, string, string, string] = [
    "TARJETA",
    "FECHA",
    "DESCRIPCION",
    "VALOR (COP)",
  ];
  const detail: (string | number)[][] = [detailHeader];
  const totalsByLabel = new Map<string, number>();
  let grandTotal = 0;

  for (const e of rows) {
    const label = aliasFor(e, cardMap, methodMap);
    const amount = Number(e.amount);
    grandTotal += amount;
    detail.push([
      label,
      formatLocalDate(e.date, offsetMinutes),
      (e.description ?? "").trim(),
      formatCopAmount(amount),
    ]);
    totalsByLabel.set(label, (totalsByLabel.get(label) ?? 0) + amount);
  }

  detail.push(["TOTAL", "", "", formatCopAmount(grandTotal)]);

  const totalsSheet: (string | number)[][] = [
    ["TARJETA", "TOTAL (COP)"],
  ];
  const sortedLabels = [...totalsByLabel.keys()].sort((a, b) =>
    a.localeCompare(b, "es", { sensitivity: "base" })
  );
  let sumPerCardSheet = 0;
  for (const label of sortedLabels) {
    const v = totalsByLabel.get(label) ?? 0;
    sumPerCardSheet += v;
    totalsSheet.push([
      label,
      formatCopAmount(v),
    ]);
  }
  totalsSheet.push(["TOTAL", formatCopAmount(sumPerCardSheet)]);

  const wb = XLSX.utils.book_new();
  const wsDetail = XLSX.utils.aoa_to_sheet(detail);
  const dataRows = rows.length;
  applyDetailSheetPresentation(wsDetail, dataRows);
  XLSX.utils.book_append_sheet(wb, wsDetail, "Detalle");

  const wsTotals = XLSX.utils.aoa_to_sheet(totalsSheet);
  applyTotalsSheetPresentation(wsTotals, sortedLabels.length);
  XLSX.utils.book_append_sheet(wb, wsTotals, "Totales por tarjeta");

  const out = XLSX.write(wb, {
    bookType: "xlsx",
    type: "array",
    cellStyles: true,
  }) as Uint8Array;
  return out;
}

function buildEmailHtml(params: {
  primaryGreen: string;
  periodLabel: string;
  rowCount: number;
  total: number;
}): string {
  const { primaryGreen, periodLabel, rowCount, total } = params;
  const totalStr = formatCopAmount(total);
  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Egresos</title>
</head>
<body style="margin:0;padding:0;background:#f4fbf7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#1c1c1e;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4fbf7;padding:24px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width:520px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 24px rgba(0,0,0,0.06);">
          <tr>
            <td style="padding:24px 24px 8px;background:linear-gradient(135deg,${primaryGreen},#27ae60);color:#ffffff;">
              <div style="font-size:13px;letter-spacing:0.04em;opacity:0.9;text-transform:uppercase;">Perfinance</div>
              <h1 style="margin:8px 0 0;font-size:22px;font-weight:700;line-height:1.2;">Exportación de egresos</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:24px;">
              <p style="margin:0 0 16px;font-size:15px;line-height:1.5;">Adjuntamos un archivo Excel (.xlsx) con dos hojas: detalle de movimientos y totales por tarjeta.</p>
              <table role="presentation" width="100%" style="border-collapse:collapse;background:#f0f9f4;border-radius:12px;border:1px solid #d4eedc;">
                <tr>
                  <td style="padding:16px;">
                    <div style="font-size:12px;color:#666;margin-bottom:4px;">Periodo</div>
                    <div style="font-size:16px;font-weight:600;color:#1c1c1e;">${escapeHtml(
                      periodLabel,
                    )}</div>
                  </td>
                </tr>
                <tr>
                  <td style="padding:0 16px 16px;">
                    <table width="100%" style="border-collapse:collapse;">
                      <tr>
                        <td style="width:50%;vertical-align:top;">
                          <div style="font-size:12px;color:#666;margin-bottom:4px;">Movimientos</div>
                          <div style="font-size:18px;font-weight:700;color:${primaryGreen};">${rowCount}</div>
                        </td>
                        <td style="width:50%;vertical-align:top;">
                          <div style="font-size:12px;color:#666;margin-bottom:4px;">Total</div>
                          <div style="font-size:18px;font-weight:700;color:${primaryGreen};">${totalStr}</div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
              <p style="margin:20px 0 0;font-size:13px;color:#888;line-height:1.4;">Generado desde Perfinance. Hoja &quot;Detalle&quot;: TARJETA, FECHA, DESCRIPCION, VALOR (COP), más fila TOTAL. Hoja &quot;Totales por tarjeta&quot;: sumas por medio y fila TOTAL.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 24px 24px;border-top:1px solid #eee;font-size:12px;color:#aaa;">
              Este mensaje es automático; responde a tu correo si necesitas ayuda con la app.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function sanitizeFilenamePart(s: string): string {
  return s.replace(/[^a-zA-Z0-9._-]+/g, "_").slice(0, 40);
}

/** Valor del secreto MAIL_FROM (Dashboard a veces guarda comillas envolviendo todo el string). */
function normalizeMailFrom(raw: string): string {
  let s = raw.trim();
  if (
    (s.startsWith('"') && s.endsWith('"')) ||
    (s.startsWith("'") && s.endsWith("'"))
  ) {
    s = s.slice(1, -1).trim();
  }
  return s;
}

type JwtPayload = {
  email?: string;
  user_metadata?: Record<string, unknown>;
  app_metadata?: Record<string, unknown>;
};

function pickStringEmail(v: unknown): string | null {
  return typeof v === "string" && v.includes("@") && v.trim().length > 0
    ? v.trim()
    : null;
}

/** Email en access token (fallback si getUser no incluye email). */
function emailFromJwtAuthHeader(authHeader: string): string | null {
  try {
    const m = authHeader.match(/^Bearer\s+(.+)$/i);
    if (!m) return null;
    const token = m[1];
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    let b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const pad = b64.length % 4 === 0 ? "" : "=".repeat(4 - (b64.length % 4));
    const json = atob(b64 + pad);
    const payload = JSON.parse(json) as JwtPayload;
    const direct = pickStringEmail(payload.email);
    const um = payload.user_metadata ?? {};
    const am = payload.app_metadata ?? {};
    const fromUm =
      pickStringEmail(um["email"]) ??
      pickStringEmail(um["email_address"]);
    const fromAm = pickStringEmail(am["email"]);
    return direct ?? fromUm ?? fromAm ?? null;
  } catch {
    return null;
  }
}

/** GoTrue a veces deja el correo solo en identities (p. ej. OAuth). */
function emailFromAuthUser(user: {
  email?: string | null;
  identities?: Array<{ identity_data?: Record<string, unknown> }>;
}): string | null {
  const u = user.email?.trim();
  if (u && u.includes("@")) return u;
  for (const id of user.identities ?? []) {
    const raw = id.identity_data?.["email"];
    const e = pickStringEmail(raw);
    if (e) return e;
  }
  return null;
}

function normalizeClientEmail(raw: string | undefined): string | null {
  if (typeof raw !== "string") return null;
  const t = raw.trim();
  return pickStringEmail(t);
}

function authorizationHeader(req: Request): string | null {
  return req.headers.get("Authorization") ?? req.headers.get("authorization");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const authHeader = authorizationHeader(req);
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const {
    windowStartIso,
    windowEndIso,
    timezoneOffsetMinutes = 0,
    recipientEmail: recipientEmailFromBody,
  } = body;
  if (!windowStartIso || !windowEndIso) {
    return new Response(
      JSON.stringify({
        error: "windowStartIso and windowEndIso are required",
      }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const periodDescription = subjectPeriodDescription(
    windowStartIso,
    windowEndIso,
    timezoneOffsetMinutes,
  );

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const jwtToken = authHeader.replace(/^Bearer\s+/i, "").trim();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser(jwtToken);

  if (userError || !user) {
    return new Response(
      JSON.stringify({
        error: "Invalid or expired session",
        detail: userError?.message ?? null,
      }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  const fromAuth = emailFromAuthUser(user);
  const fromBody = normalizeClientEmail(recipientEmailFromBody);
  const fromJwt = emailFromJwtAuthHeader(authHeader);

  const recipientEmail = fromAuth ?? fromBody ?? fromJwt;
  if (!recipientEmail) {
    console.error("resolve email: user has no email", "jwt_len", jwtToken.length);
    return new Response(
      JSON.stringify({
        error: "Unable to resolve user email",
        hint:
          "Inicia sesión con un método que tenga correo o actualiza la app.",
      }),
      { status: 422, headers: { "Content-Type": "application/json" } },
    );
  }

  const { data: expenses, error: expError } = await supabase
    .from("expenses")
    .select(
      "id, amount, date, payment_type, payment_ref, description",
    )
    .gte("date", windowStartIso)
    .lte("date", windowEndIso)
    .order("date", { ascending: false });

  if (expError) {
    console.error(expError);
    return new Response(JSON.stringify({ error: "Failed to load expenses" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const rows = (expenses ?? []) as ExpenseRow[];

  const { data: cards } = await supabase
    .from("credit_cards")
    .select("id, alias");
  const { data: methods } = await supabase
    .from("payment_methods")
    .select("id, name");

  const cardMap = new Map<string, string>(
    ((cards ?? []) as CardRow[]).map((c) => [c.id, c.alias]),
  );
  const methodMap = new Map<string, string>(
    ((methods ?? []) as MethodRow[]).map((m) => [m.id, m.name]),
  );

  const workbookBytes = buildExpenseWorkbook(
    rows,
    cardMap,
    methodMap,
    timezoneOffsetMinutes,
  );
  const total = rows.reduce((s, e) => s + Number(e.amount), 0);
  const html = buildEmailHtml({
    primaryGreen: "#2ECC71",
    periodLabel: periodDescription,
    rowCount: rows.length,
    total,
  });

  const resendKey = Deno.env.get("RESEND_API_KEY")?.trim();
  const mailFromRaw = Deno.env.get("MAIL_FROM") ?? Deno.env.get("EMAIL_FROM");
  const mailFrom = mailFromRaw ? normalizeMailFrom(mailFromRaw) : "";
  if (!resendKey || !mailFrom) {
    return new Response(
      JSON.stringify({
        error: "Email not configured on server",
        hint:
          "Define Secrets RESEND_API_KEY y MAIL_FROM (nombre exacto). Formato recomendado: "
            + `"Perfinance <contact@tu-dominio-verificado-en-resend.com>"`,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const now = new Date();
  const stamp = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}${
    String(now.getDate()).padStart(2, "0")
  }_${String(now.getHours()).padStart(2, "0")}${String(now.getMinutes()).padStart(2, "0")}`;
  const filename =
    `egresos_${sanitizeFilenamePart(periodDescription)}_${stamp}.xlsx`;

  const attachmentB64 = encodeBase64(workbookBytes);
  if (!attachmentB64 || attachmentB64.length === 0) {
    console.error("[send-expense-export] attachment empty after encode");
    return new Response(
      JSON.stringify({ error: "Generated attachment was empty" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const subject =
    `Egresos — ${periodDescription} (${stamp.replace("_", " ")})`;

  // Tope mensual de correos de la cuenta (migración 020). Se reserva justo antes
  // de enviar y se devuelve si Resend falla.
  const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  let claim: EmailClaim;
  try {
    claim = await claimEmailSend(admin, user.id, "expense_export", recipientEmail);
  } catch (e) {
    console.error("[send-expense-export] quota check failed", e);
    return new Response(
      JSON.stringify({ error: "Could not verify email quota" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
  if (!claim.allowed) {
    return new Response(
      JSON.stringify({ error: quotaExceededMessage(claim.quota), code: "monthly_email_limit" }),
      { status: 429, headers: { "Content-Type": "application/json" } },
    );
  }

  // API REST: usar `contentType` (camelCase) como el SDK de Node; `content_type` puede invalidar el adjunto.
  const resendRes = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: mailFrom,
      to: [recipientEmail],
      subject,
      html,
      attachments: [{
        filename,
        content: attachmentB64,
        contentType:
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      }],
    }),
  });

  const resendText = await resendRes.text();
  let resendJson: Record<string, unknown>;
  try {
    resendJson = JSON.parse(resendText) as Record<string, unknown>;
  } catch {
    resendJson = { rawBody: resendText.slice(0, 1200) };
  }

  if (!resendRes.ok) {
    const resendMsg = typeof resendJson.message === "string"
      ? resendJson.message
      : undefined;
    console.error(
      "[send-expense-export] Resend HTTP",
      resendRes.status,
      resendText,
    );
    await releaseEmailSend(admin, claim.logId);
    // 4xx de Resend = configuración (dominio, modo prueba, etc.); 5xx = incidente Resend.
    const fnStatus = resendRes.status >= 400 && resendRes.status < 500
      ? 422
      : 502;
    return new Response(
      JSON.stringify({
        error: "Failed to send email",
        detail: resendJson,
        ...(resendMsg ? { hint: resendMsg } : {}),
      }),
      { status: fnStatus, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(
    JSON.stringify({
      ok: true,
      message: "Correo enviado",
      rows: rows.length,
      resendId: (resendJson as { id?: string }).id ?? null,
    }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    },
  );
});
