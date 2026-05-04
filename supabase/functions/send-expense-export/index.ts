import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from '@supabase/supabase-js';
import XLSX from 'xlsx-js-style';

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
  '',
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const copCurrency = new Intl.NumberFormat('es-CO', {
  style: 'currency',
  currency: 'COP',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

/** Monto en COP para Excel y correo (p. ej. `$ 1.234.567`). */
function formatCopAmount(n: number): string {
  return copCurrency.format(n);
}

function capitalizeEs(s: string): string {
  if (!s) return s;
  return s.charAt(0).toLocaleUpperCase('es') + s.slice(1);
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

  const sameDay = start.y === end.y && start.m === end.m && start.d === end.d;

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
    return `${capitalizeEs(MONTH_NAMES_ES[start.m])}-${capitalizeEs(
      MONTH_NAMES_ES[end.m],
    )} ${start.y}`;
  }

  return `${capitalizeEs(MONTH_NAMES_ES[start.m])} ${start.y}-${capitalizeEs(
    MONTH_NAMES_ES[end.m],
  )} ${end.y}`;
}

/** Aproxima `DateTime.parse(iso).toLocal()` usando el offset enviado desde el cliente. */
function formatLocalDate(isoDate: string, offsetMinutes: number): string {
  const instant = Date.parse(isoDate);
  const shifted = instant + offsetMinutes * 60 * 1000;
  const u = new Date(shifted);
  const dd = String(u.getUTCDate()).padStart(2, '0');
  const mm = String(u.getUTCMonth() + 1).padStart(2, '0');
  const yyyy = u.getUTCFullYear();
  return `${dd}/${mm}/${yyyy}`;
}

function aliasFor(
  e: ExpenseRow,
  cardMap: Map<string, string>,
  methodMap: Map<string, string>,
): string {
  if (e.payment_type === 'credit_card') {
    return cardMap.get(e.payment_ref) ?? 'Tarjeta';
  }
  return methodMap.get(e.payment_ref) ?? 'Medio';
}

const thinBorder = {
  top: { style: 'thin', color: { rgb: 'CCCCCC' } },
  bottom: { style: 'thin', color: { rgb: 'CCCCCC' } },
  left: { style: 'thin', color: { rgb: 'CCCCCC' } },
  right: { style: 'thin', color: { rgb: 'CCCCCC' } },
};

type StyledCell = { s?: Record<string, unknown> };
type MutableSheet = Record<string, unknown>;

function setCellStyle(
  addr: string,
  ws: MutableSheet,
  style: Record<string, unknown>,
) {
  const cell = ws[addr] as StyledCell | undefined;
  if (!cell || typeof cell !== 'object') return;
  cell.s = style;
}

/** Encabezado verde, filas alternadas, fila TOTAL resaltada. */
function applyDetailSheetPresentation(ws: MutableSheet, dataRowCount: number) {
  const cols = 4;
  const headerRow = 0;
  const totalRow = dataRowCount + 1;

  ws['!cols'] = [{ wch: 26 }, { wch: 12 }, { wch: 44 }, { wch: 18 }];
  ws['!rows'] = [{ hpt: 22 }];

  const headerStyle = {
    font: { bold: true, color: { rgb: 'FFFFFF' } },
    fill: { patternType: 'solid', fgColor: { rgb: '217346' } },
    alignment: { horizontal: 'center', vertical: 'center', wrapText: true },
    border: thinBorder,
  };

  for (let c = 0; c < cols; c++) {
    const addr = XLSX.utils.encode_cell({ r: headerRow, c });
    setCellStyle(addr, ws, headerStyle);
  }

  for (let r = 1; r <= dataRowCount; r++) {
    const fillRgb = r % 2 === 1 ? 'FAFAFA' : 'FFFFFF';
    const rowStyle = {
      alignment: {
        horizontal: 'left',
        vertical: 'center',
        wrapText: true,
      },
      fill: { patternType: 'solid', fgColor: { rgb: fillRgb } },
      border: thinBorder,
    };
    const numStyle = {
      ...rowStyle,
      alignment: { horizontal: 'right', vertical: 'center', wrapText: true },
    };
    for (let c = 0; c < cols; c++) {
      const addr = XLSX.utils.encode_cell({ r, c });
      setCellStyle(addr, ws, c === cols - 1 ? numStyle : rowStyle);
    }
  }

  const totalFill = 'E8F5E9';
  for (let c = 0; c < cols; c++) {
    const addr = XLSX.utils.encode_cell({ r: totalRow, c });
    const isAmountCol = c === cols - 1;
    setCellStyle(addr, ws, {
      font: { bold: true },
      fill: { patternType: 'solid', fgColor: { rgb: totalFill } },
      alignment: isAmountCol
        ? { horizontal: 'right', vertical: 'center' }
        : { horizontal: 'left', vertical: 'center' },
      border: thinBorder,
    });
  }
}

/** Misma línea visual que Detalle (2 columnas). */
function applyTotalsSheetPresentation(ws: MutableSheet, labelRowCount: number) {
  const cols = 2;
  const headerRow = 0;
  const totalRow = labelRowCount + 1;

  ws['!cols'] = [{ wch: 30 }, { wch: 20 }];
  ws['!rows'] = [{ hpt: 22 }];

  const headerStyle = {
    font: { bold: true, color: { rgb: 'FFFFFF' } },
    fill: { patternType: 'solid', fgColor: { rgb: '217346' } },
    alignment: { horizontal: 'center', vertical: 'center', wrapText: true },
    border: thinBorder,
  };

  for (let c = 0; c < cols; c++) {
    const addr = XLSX.utils.encode_cell({ r: headerRow, c });
    setCellStyle(addr, ws, headerStyle);
  }

  for (let r = 1; r <= labelRowCount; r++) {
    const fillRgb = r % 2 === 1 ? 'FAFAFA' : 'FFFFFF';
    const left = {
      alignment: { horizontal: 'left', vertical: 'center', wrapText: true },
      fill: { patternType: 'solid', fgColor: { rgb: fillRgb } },
      border: thinBorder,
    };
    const right = {
      alignment: { horizontal: 'right', vertical: 'center', wrapText: true },
      fill: { patternType: 'solid', fgColor: { rgb: fillRgb } },
      border: thinBorder,
    };
    setCellStyle(XLSX.utils.encode_cell({ r, c: 0 }), ws, left);
    setCellStyle(XLSX.utils.encode_cell({ r, c: 1 }), ws, right);
  }

  const totalFill = 'E8F5E9';
  for (let c = 0; c < cols; c++) {
    const addr = XLSX.utils.encode_cell({ r: totalRow, c });
    const isAmountCol = c === 1;
    setCellStyle(addr, ws, {
      font: { bold: true },
      fill: { patternType: 'solid', fgColor: { rgb: totalFill } },
      alignment: isAmountCol
        ? { horizontal: 'right', vertical: 'center' }
        : { horizontal: 'left', vertical: 'center' },
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
    'TARJETA',
    'FECHA',
    'DESCRIPCION',
    'VALOR (COP)',
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
      (e.description ?? '').trim(),
      formatCopAmount(amount),
    ]);
    totalsByLabel.set(label, (totalsByLabel.get(label) ?? 0) + amount);
  }

  detail.push(['TOTAL', '', '', formatCopAmount(grandTotal)]);

  const totalsSheet: (string | number)[][] = [['TARJETA', 'TOTAL (COP)']];
  const sortedLabels = [...totalsByLabel.keys()].sort((a, b) =>
    a.localeCompare(b, 'es', { sensitivity: 'base' }),
  );
  let sumPerCardSheet = 0;
  for (const label of sortedLabels) {
    const v = totalsByLabel.get(label) ?? 0;
    sumPerCardSheet += v;
    totalsSheet.push([label, formatCopAmount(v)]);
  }
  totalsSheet.push(['TOTAL', formatCopAmount(sumPerCardSheet)]);

  const wb = XLSX.utils.book_new();
  const wsDetail = XLSX.utils.aoa_to_sheet(detail);
  const dataRows = rows.length;
  applyDetailSheetPresentation(wsDetail, dataRows);
  XLSX.utils.book_append_sheet(wb, wsDetail, 'Detalle');

  const wsTotals = XLSX.utils.aoa_to_sheet(totalsSheet);
  applyTotalsSheetPresentation(wsTotals, sortedLabels.length);
  XLSX.utils.book_append_sheet(wb, wsTotals, 'Totales por tarjeta');

  const raw = XLSX.write(wb, {
    bookType: 'xlsx',
    type: 'array',
    cellStyles: true,
  }) as number[];
  return new Uint8Array(raw);
}

function sanitizeFilenamePart(s: string): string {
  return s.replace(/[^a-zA-Z0-9._-]+/g, '_').slice(0, 40);
}

type JwtPayload = {
  email?: string;
  user_metadata?: Record<string, unknown>;
  app_metadata?: Record<string, unknown>;
};

function pickStringEmail(v: unknown): string | null {
  return typeof v === 'string' && v.includes('@') && v.trim().length > 0
    ? v.trim()
    : null;
}

/** Email en access token (fallback si getUser no incluye email). */
function emailFromJwtAuthHeader(authHeader: string): string | null {
  try {
    const m = authHeader.match(/^Bearer\s+(.+)$/i);
    if (!m) return null;
    const token = m[1];
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    let b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const pad = b64.length % 4 === 0 ? '' : '='.repeat(4 - (b64.length % 4));
    const json = atob(b64 + pad);
    const payload = JSON.parse(json) as JwtPayload;
    const direct = pickStringEmail(payload.email);
    const um = payload.user_metadata ?? {};
    const am = payload.app_metadata ?? {};
    const fromUm =
      pickStringEmail(um['email']) ?? pickStringEmail(um['email_address']);
    const fromAm = pickStringEmail(am['email']);
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
  if (u && u.includes('@')) return u;
  for (const id of user.identities ?? []) {
    const raw = id.identity_data?.['email'];
    const e = pickStringEmail(raw);
    if (e) return e;
  }
  return null;
}

function normalizeClientEmail(raw: string | undefined): string | null {
  if (typeof raw !== 'string') return null;
  const t = raw.trim();
  return pickStringEmail(t);
}

function authorizationHeader(req: Request): string | null {
  return req.headers.get('Authorization') ?? req.headers.get('authorization');
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers':
          'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const authHeader = authorizationHeader(req);
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
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
        error: 'windowStartIso and windowEndIso are required',
      }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  if (isNaN(Date.parse(windowStartIso)) || isNaN(Date.parse(windowEndIso))) {
    return new Response(
      JSON.stringify({ error: 'windowStartIso and windowEndIso must be valid ISO 8601 strings' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const periodDescription = subjectPeriodDescription(
    windowStartIso,
    windowEndIso,
    timezoneOffsetMinutes,
  );

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const emailApiService = Deno.env.get('EMAIL_API_SERVICE');
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const jwtToken = authHeader.replace(/^Bearer\s+/i, '').trim();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser(jwtToken);

  if (userError && !user) {
    return new Response(
      JSON.stringify({
        error: 'Invalid or expired session',
        detail: userError.message,
      }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const fromAuth = user ? emailFromAuthUser(user) : null;
  const fromBody = normalizeClientEmail(recipientEmailFromBody);
  const fromJwt = emailFromJwtAuthHeader(authHeader);

  const recipientEmail = fromAuth ?? fromBody ?? fromJwt;
  if (!recipientEmail) {
    console.error(
      'resolve email',
      userError?.message ?? '(no userError)',
      'has_user',
      Boolean(user),
      'jwt_len',
      jwtToken.length,
    );
    return new Response(
      JSON.stringify({
        error: 'Unable to resolve user email',
        hint: 'Inicia sesión con un método que tenga correo o actualiza la app.',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const { data: expenses, error: expError } = await supabase
    .from('expenses')
    .select('id, amount, date, payment_type, payment_ref, description')
    .gte('date', windowStartIso)
    .lte('date', windowEndIso)
    .order('date', { ascending: false });

  if (expError) {
    console.error(expError);
    return new Response(JSON.stringify({ error: 'Failed to load expenses' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const rows = (expenses ?? []) as ExpenseRow[];

  if (rows.length === 0) {
    return new Response(
      JSON.stringify({ error: 'No expenses found for the given date range' }),
      { status: 404, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const { data: cards } = await supabase
    .from('credit_cards')
    .select('id, alias');
  const { data: methods } = await supabase
    .from('payment_methods')
    .select('id, name');

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

  const emailApiKey = Deno.env.get('EMAIL_SERVICE_API_KEY')?.trim();

  if (!emailApiKey || !emailApiService) {
    return new Response(
      JSON.stringify({
        error: 'Email not configured on server',
        hint: 'Define Secrets EMAIL_SERVICE_API_KEY y EMAIL_API_SERVICE.',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const now = new Date();
  const stamp = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(
    now.getDate(),
  ).padStart(
    2,
    '0',
  )}_${String(now.getHours()).padStart(2, '0')}${String(now.getMinutes()).padStart(2, '0')}`;
  const filename = `egresos_${sanitizeFilenamePart(periodDescription)}_${stamp}.xlsx`;

  const form = new FormData();
  form.append('to', recipientEmail);
  form.append('template', 'send-expense-report');
  form.append(
    'fields',
    JSON.stringify({
      periodLabel: periodDescription,
      rowCount: rows.length,
      totalStr: formatCopAmount(total),
      stamp: stamp.replace('_', ' '),
    }),
  );
  form.append(
    'attachments',
    new Blob([workbookBytes as Uint8Array<ArrayBuffer>], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    }),
    filename,
  );

  const emailRes = await fetch(emailApiService, {
    method: 'POST',
    headers: { 'x-api-key': emailApiKey },
    body: form,
  });

  const emailText = await emailRes.text();
  let emailJson: Record<string, unknown>;
  try {
    emailJson = JSON.parse(emailText) as Record<string, unknown>;
  } catch {
    emailJson = { rawBody: emailText.slice(0, 1200) };
  }

  if (!emailRes.ok) {
    console.error(
      '[send-expense-export] email service HTTP',
      emailRes.status,
      emailText,
    );
    const fnStatus =
      emailRes.status >= 400 && emailRes.status < 500 ? 422 : 502;
    return new Response(
      JSON.stringify({ error: 'Failed to send email', detail: emailJson }),
      { status: fnStatus, headers: { 'Content-Type': 'application/json' } },
    );
  }

  return new Response(
    JSON.stringify({
      ok: true,
      message: 'Correo enviado',
      rows: rows.length,
    }),
    {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    },
  );
});
