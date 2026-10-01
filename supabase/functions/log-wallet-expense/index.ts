import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import {
  type Assignment,
  cardKey,
  localWallTimestamp,
  parseAmount,
  resolveTarget,
  type Target,
} from "./wallet.ts";

// Registra un egreso desde un atajo de iOS (automatización de Wallet) sin abrir
// la app. No usa el JWT de sesión (expira): se autentica con un token personal
// creado por la app con la RPC create_shortcut_token, del que solo se guarda el hash.

const DESCRIPTION_PREFIX = "[Wallet]: ";

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "Usar POST" });

  const token = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return json(401, { error: "Falta el token del atajo" });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "El cuerpo debe ser JSON" });
  }

  const amount = parseAmount(body.amount);
  if (amount === null) {
    return json(400, { error: "Monto inválido", recibido: body.amount ?? null });
  }
  const merchant = typeof body.merchant === "string" ? body.merchant.trim() : "";
  const cardName = typeof body.card === "string" ? body.card.trim() : "";

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data: tokenRow } = await admin
    .from("shortcut_tokens")
    .select("user_id, utc_offset_minutes")
    .eq("token_hash", await sha256Hex(token))
    .maybeSingle();
  if (!tokenRow) return json(401, { error: "Token inválido o revocado" });
  const userId = tokenRow.user_id as string;

  const [cards, methods] = await Promise.all([
    admin.from("credit_cards").select("id, alias").eq("user_id", userId).eq("is_active", true),
    admin.from("payment_methods").select("id, name").eq("user_id", userId),
  ]);
  if (cards.error || methods.error) {
    return json(500, { error: "No se pudieron leer las tarjetas" });
  }
  const targets: Target[] = [
    ...cards.data.map((c) => ({ type: "credit_card" as const, id: c.id, name: c.alias })),
    ...methods.data.map((m) => ({ type: "payment_method" as const, id: m.id, name: m.name })),
  ];

  const key = cardKey(cardName);
  let assignment: Assignment = null;
  if (key) {
    const { data } = await admin
      .from("wallet_cards")
      .select("payment_type, payment_ref")
      .eq("user_id", userId)
      .eq("name_key", key)
      .maybeSingle();
    assignment = data;
  }

  let paymentType: string;
  let paymentRef: string;
  const { target: matched } = resolveTarget(cardName, targets, assignment);
  if (matched) {
    paymentType = matched.type;
    paymentRef = matched.id;
  } else {
    // Queda anotada para que el usuario la asigne una vez desde la app.
    if (key && !assignment) {
      await admin
        .from("wallet_cards")
        .upsert(
          { user_id: userId, name_key: key, wallet_name: cardName },
          { onConflict: "user_id,name_key", ignoreDuplicates: true },
        );
    }
    // El egreso no se pierde: va al último medio usado y queda marcado para corregir.
    const { data: last } = await admin
      .from("expenses")
      .select("payment_type, payment_ref")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (!last) {
      return json(422, { error: "No hay tarjetas ni medios de pago para asignar el egreso" });
    }
    paymentType = last.payment_type;
    paymentRef = last.payment_ref;
  }

  const description = DESCRIPTION_PREFIX + (merchant || "Pago") +
    (matched ? "" : ` (tarjeta sin identificar: ${cardName || "desconocida"})`);

  const { error: insertError } = await admin.from("expenses").insert({
    user_id: userId,
    amount,
    date: localWallTimestamp(new Date(), tokenRow.utc_offset_minutes as number),
    payment_type: paymentType,
    payment_ref: paymentRef,
    description,
  });
  if (insertError) {
    console.error("log-wallet-expense insert failed", insertError);
    return json(500, { error: "No se pudo registrar el egreso" });
  }

  await admin
    .from("shortcut_tokens")
    .update({ last_used_at: new Date().toISOString() })
    .eq("user_id", userId);

  return json(200, {
    ok: true,
    matched: matched !== null,
    message: matched
      ? `Egreso registrado en ${matched.name}`
      : `Egreso registrado, pero no reconocí la tarjeta "${cardName}". Asignala en Perfinance → Apple Wallet.`,
  });
});
