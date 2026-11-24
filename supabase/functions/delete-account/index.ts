import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

// Elimina la cuenta del usuario autenticado (requisito de Google Play).
//
// Las tablas con user_id tienen ON DELETE CASCADE hacia auth.users, así que
// borrar el usuario borra sus datos. Lo único que no cae en cascada son las
// deudas espejo que ven sus deudores (mirrored_debts.creditor_user_id no tiene
// FK y el trigger de borrado de receivables solo las marca 'revoked'): se
// borran antes, junto con sus pagos (cascade de mirrored_debt_payments).
// Las deudas que este usuario tiene con otros son de esos otros y se quedan.

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const authHeader = req.headers.get("Authorization") ?? req.headers.get("authorization");
  if (!authHeader) return json(401, { error: "Missing Authorization" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  const { data: { user }, error: userError } = await userClient.auth.getUser(jwt);
  if (userError || !user) return json(401, { error: "Invalid or expired session" });

  const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  const { error: mirrorsError } = await admin
    .from("mirrored_debts")
    .delete()
    .eq("creditor_user_id", user.id);
  if (mirrorsError) {
    console.error("[delete-account] mirrored_debts delete failed", mirrorsError);
    return json(500, { error: "Could not delete account" });
  }

  // Si esto falla después de borrar los espejos, la cuenta sigue activa y el
  // usuario puede reintentar; los espejos se recrean si vuelve a editar un cobro.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("[delete-account] deleteUser failed", deleteError);
    return json(500, { error: "Could not delete account" });
  }

  return json(200, { ok: true });
});
