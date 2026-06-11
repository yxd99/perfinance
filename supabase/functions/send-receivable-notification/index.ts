import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

type NotificationEvent =
  | "created"
  | "payment_recorded"
  | "payment_edited"
  | "payment_deleted";

type Body = {
  event: NotificationEvent;
  recipientEmail: string;
  debtorName: string;
  totalAmount: number;
  remainingBalance: number;
  /** The creditor's email — always included (spec S5). */
  creditorEmail?: string;
  /** True when the debtor is a registered app user.
   * Drives the email template to mention app visibility. */
  isRegistered?: boolean;
  paymentAmount?: number;
  paymentDate?: string;
};

const MONTH_NAMES_ES = [
  "",
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
];

const copCurrency = new Intl.NumberFormat("es-CO", {
  style: "currency",
  currency: "COP",
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

function formatCopAmount(n: number): string {
  return copCurrency.format(n);
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function formatReadableDate(isoDate: string): string {
  const d = new Date(isoDate);
  const day = d.getUTCDate();
  const month = MONTH_NAMES_ES[d.getUTCMonth() + 1];
  const year = d.getUTCFullYear();
  return `${day} de ${month} de ${year}`;
}

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

function authorizationHeader(req: Request): string | null {
  return req.headers.get("Authorization") ?? req.headers.get("authorization");
}

type EventMeta = { subject: string; title: string; intro: string };

function eventMeta(
  event: NotificationEvent,
  debtorName: string,
  creditorEmail?: string,
  isRegistered?: boolean,
): EventMeta {
  const name = escapeHtml(debtorName);
  const creditorInfo = creditorEmail
    ? ` (registrada por <strong>${escapeHtml(creditorEmail)}</strong>)`
    : "";
  const appVisibility =
    isRegistered && event === "created"
      ? ` Podés verla en tu app PerFinance.`
      : "";

  switch (event) {
    case "created":
      return {
        subject: `Nueva deuda registrada — PerFinance`,
        title: "Nueva deuda registrada",
        intro: `Hola <strong>${name}</strong>, se ha registrado una deuda a tu nombre${creditorInfo}.${appVisibility}`,
      };
    case "payment_recorded":
      return {
        subject: `Cobro registrado — PerFinance`,
        title: "Cobro registrado",
        intro: `Hola <strong>${name}</strong>, se ha registrado un cobro en tu cuenta${creditorInfo}.`,
      };
    case "payment_edited":
      return {
        subject: `Cobro modificado — PerFinance`,
        title: "Cobro modificado",
        intro: `Hola <strong>${name}</strong>, se ha modificado un cobro en tu cuenta${creditorInfo}.`,
      };
    case "payment_deleted":
      return {
        subject: `Cobro eliminado — PerFinance`,
        title: "Cobro eliminado",
        intro: `Hola <strong>${name}</strong>, se ha eliminado un cobro de tu cuenta${creditorInfo}.`,
      };
  }
}

function buildEmailHtml(body: Body): string {
  const {
    event,
    debtorName,
    totalAmount,
    remainingBalance,
    paymentAmount,
    paymentDate,
    creditorEmail,
    isRegistered,
  } = body;
  const primaryGreen = "#2ECC71";
  const meta = eventMeta(event, debtorName, creditorEmail, isRegistered);
  const isFullyPaid = remainingBalance <= 0;

  const paymentRow = paymentAmount != null
    ? `<tr>
        <td style="padding:8px 0;border-bottom:1px solid #eef;">
          <span style="font-size:12px;color:#666;">${event === "payment_deleted" ? "Monto eliminado" : "Monto abonado"}</span><br/>
          <span style="font-size:16px;font-weight:700;color:${primaryGreen};">${formatCopAmount(paymentAmount)}</span>
        </td>
       </tr>`
    : "";

  const dateRow = paymentDate
    ? `<tr>
        <td style="padding:8px 0;border-bottom:1px solid #eef;">
          <span style="font-size:12px;color:#666;">Fecha</span><br/>
          <span style="font-size:15px;font-weight:600;color:#1c1c1e;">${formatReadableDate(paymentDate)}</span>
        </td>
       </tr>`
    : "";

  const paidBanner = isFullyPaid && event !== "payment_deleted"
    ? `<div style="margin-top:16px;padding:12px 16px;background:#e8f5e9;border-radius:8px;border:1px solid #c8e6c9;font-size:14px;color:#2e7d32;font-weight:600;">
         ✓ ¡Deuda saldada en su totalidad!
       </div>`
    : "";

  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>${meta.title}</title>
</head>
<body style="margin:0;padding:0;background:#f4fbf7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#1c1c1e;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4fbf7;padding:24px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width:520px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 24px rgba(0,0,0,0.06);">
          <tr>
            <td style="padding:24px 24px 8px;background:linear-gradient(135deg,${primaryGreen},#27ae60);color:#ffffff;">
              <div style="font-size:13px;letter-spacing:0.04em;opacity:0.9;text-transform:uppercase;">Perfinance</div>
              <h1 style="margin:8px 0 0;font-size:22px;font-weight:700;line-height:1.2;">${meta.title}</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:24px;">
              <p style="margin:0 0 16px;font-size:15px;line-height:1.5;">${meta.intro}</p>
              <table role="presentation" width="100%" style="border-collapse:collapse;background:#f0f9f4;border-radius:12px;border:1px solid #d4eedc;">
                <tr>
                  <td style="padding:16px;">
                    <table width="100%" style="border-collapse:collapse;">
                      ${paymentRow}
                      ${dateRow}
                      <tr>
                        <td style="padding:8px 0;">
                          <span style="font-size:12px;color:#666;">Falta por pagar</span><br/>
                          <span style="font-size:18px;font-weight:700;color:${isFullyPaid ? primaryGreen : "#e53e3e"};">${isFullyPaid ? "Saldado ✓" : formatCopAmount(remainingBalance)}</span>
                        </td>
                      </tr>
                    </table>
                    ${paidBanner}
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 24px 24px;border-top:1px solid #eee;font-size:12px;color:#aaa;">
              Este mensaje es automático generado desde Perfinance.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
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

  const { event, recipientEmail, debtorName, totalAmount, remainingBalance } = body;
  if (!event || !recipientEmail || !debtorName || totalAmount == null || remainingBalance == null) {
    return new Response(
      JSON.stringify({ error: "Missing required fields: event, recipientEmail, debtorName, totalAmount, remainingBalance" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  // Verify the JWT belongs to a valid Supabase user
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const jwtToken = authHeader.replace(/^Bearer\s+/i, "").trim();
  const { data: { user }, error: userError } = await supabase.auth.getUser(jwtToken);

  if (userError && !user) {
    return new Response(
      JSON.stringify({ error: "Invalid or expired session", detail: userError.message }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  const resendKey = Deno.env.get("RESEND_API_KEY")?.trim();
  const mailFromRaw = Deno.env.get("MAIL_FROM") ?? Deno.env.get("EMAIL_FROM");
  const mailFrom = mailFromRaw ? normalizeMailFrom(mailFromRaw) : "";

  if (!resendKey || !mailFrom) {
    return new Response(
      JSON.stringify({
        error: "Email not configured on server",
        hint: 'Define Secrets RESEND_API_KEY y MAIL_FROM. Formato: "Perfinance <contact@tu-dominio.com>"',
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const meta = eventMeta(event, debtorName, body.creditorEmail, body.isRegistered);
  const html = buildEmailHtml(body);

  const resendRes = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: mailFrom,
      to: [recipientEmail.trim()],
      subject: meta.subject,
      html,
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
    const resendMsg = typeof resendJson.message === "string" ? resendJson.message : undefined;
    console.error("[send-receivable-notification] Resend HTTP", resendRes.status, resendText);
    const fnStatus = resendRes.status >= 400 && resendRes.status < 500 ? 422 : 502;
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
      message: "Notificación enviada",
      event,
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
