import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { isValidEmail, normalizeEmail } from "./recipient.ts";
import { claimEmailSend, type EmailClaim, quotaExceededMessage, releaseEmailSend } from "../_shared/email_quota.ts";
import { fromWithDisplayName } from "../_shared/email_layout.ts";
import { buildNotificationEmail, type NotificationEvent } from "./templates.ts";

type Body = {
  event: NotificationEvent;
  recipientEmail: string;
  debtorName: string;
  totalAmount: number;
  remainingBalance: number;
  /** Kept for older app versions; the email uses the authenticated user's email instead. */
  creditorEmail?: string;
  /** True when the debtor is a registered app user.
   * Drives the email template to mention app visibility. */
  isRegistered?: boolean;
  paymentAmount?: number;
  paymentDate?: string;
  /** Optional receivable ID — used for ownership verification on reminder events. */
  receivableId?: string;
  /** Optional description of the receivable, shown so the debtor knows what it is about. */
  description?: string;
};

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

  if (userError || !user) {
    return new Response(
      JSON.stringify({ error: "Invalid or expired session", detail: userError?.message ?? null }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!isValidEmail(recipientEmail)) {
    return new Response(
      JSON.stringify({ error: "Invalid recipientEmail" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }
  const recipient = normalizeEmail(recipientEmail);

  // Lista de destinatarios permitidos: cada intento queda registrado y solo se
  // envía si el dueño del proyecto aprobó la fila en el dashboard de Supabase.
  const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: allowed, error: allowlistError } = await admin
    .from("email_recipient_allowlist")
    .upsert(
      { requested_by: user.id, email: recipient, last_attempt_at: new Date().toISOString() },
      { onConflict: "requested_by,email" },
    )
    .select("approved")
    .single();

  if (allowlistError || !allowed) {
    console.error("[send-receivable-notification] allowlist upsert failed", allowlistError);
    return new Response(
      JSON.stringify({ error: "Could not verify recipient" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!allowed.approved) {
    return new Response(
      JSON.stringify({ ok: true, sent: false, status: "pending_approval", event }),
      { status: 202, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } },
    );
  }

  // Ownership verification for reminder events — ensure the authenticated user owns the receivable
  if (event === "reminder" && body.receivableId) {
    const { data: ownership, error: ownershipError } = await supabase
      .from("receivables")
      .select("id")
      .eq("id", body.receivableId)
      .eq("user_id", user?.id ?? "")
      .single();

    if (ownershipError || !ownership) {
      return new Response(
        JSON.stringify({ error: "Not authorized to send reminder for this receivable" }),
        { status: 403, headers: { "Content-Type": "application/json" } },
      );
    }
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

  // Tope mensual de correos de la cuenta (migración 020).
  let claim: EmailClaim;
  try {
    claim = await claimEmailSend(admin, user.id, "receivable_notification", recipient);
  } catch (e) {
    console.error("[send-receivable-notification] quota check failed", e);
    return new Response(
      JSON.stringify({ error: "Could not verify email quota" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
  if (!claim.allowed) {
    return new Response(
      JSON.stringify({
        ok: true,
        sent: false,
        status: "quota_exceeded",
        quota: claim.quota,
        message: quotaExceededMessage(claim.quota),
        event,
      }),
      { status: 200, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } },
    );
  }

  // Quien cobra sale de la sesión, no del cuerpo: su nombre (Tu cuenta) y su
  // correo, que también es la dirección de respuesta del deudor.
  const creditorEmail = user.email ?? body.creditorEmail ?? "";
  const fullName = user.user_metadata?.full_name;
  const email = buildNotificationEmail({
    event,
    debtorName,
    description: body.description,
    totalAmount,
    remainingBalance,
    paymentAmount: body.paymentAmount,
    paymentDate: body.paymentDate,
    creditorName: typeof fullName === "string" ? fullName : null,
    creditorEmail,
    isRegistered: body.isRegistered,
  });

  const resendRes = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromWithDisplayName(mailFrom, email.fromName),
      to: [recipient],
      ...(creditorEmail ? { reply_to: creditorEmail } : {}),
      subject: email.subject,
      html: email.html,
      text: email.text,
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
    await releaseEmailSend(admin, claim.logId);
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
      sent: true,
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
