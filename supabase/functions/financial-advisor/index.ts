import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

// ─── Tool definitions ───────────────────────────────────────────────────────

const TOOLS = [
  {
    name: "get_financial_summary",
    description: "Resumen general de las finanzas del usuario: gastos del mes actual y anterior, deudas activas, pagos automáticos próximos, cuentas por cobrar. Llama esto primero para dar contexto.",
    parameters: { type: "object", properties: {}, required: [] },
  },
  {
    name: "get_expenses",
    description: "Obtiene gastos en un período. Parámetro 'query' opcional para filtrar por descripción (ej: supermercado, Netflix, etc).",
    parameters: {
      type: "object",
      properties: {
        from_date: { type: "string", description: "Fecha inicio ISO (YYYY-MM-DD). Default: inicio del mes actual." },
        to_date: { type: "string", description: "Fecha fin ISO (YYYY-MM-DD). Default: hoy." },
        query: { type: "string", description: "Texto para filtrar por descripción (opcional)." },
      },
      required: [],
    },
  },
  {
    name: "get_spending_diff",
    description: "Compara gastos entre dos períodos. Devuelve diferencia absoluta y porcentual, más breakdown por tarjeta/método.",
    parameters: {
      type: "object",
      properties: {
        period_a_from: { type: "string", description: "Fecha inicio primer período (YYYY-MM-DD)." },
        period_a_to: { type: "string", description: "Fecha fin primer período (YYYY-MM-DD)." },
        period_b_from: { type: "string", description: "Fecha inicio segundo período (YYYY-MM-DD). Si no se especifica, usa el período anterior a A." },
        period_b_to: { type: "string", description: "Fecha fin segundo período (YYYY-MM-DD). Default: hoy si no se especifica." },
      },
      required: ["period_a_from", "period_a_to"],
    },
  },
  {
    name: "get_debt_details",
    description: "Obtiene todas las deudas activas del usuario con detalle de cuotas pagadas, saldo restante y próxima cuota.",
    parameters: { type: "object", properties: {}, required: [] },
  },
  {
    name: "get_card_details",
    description: "Obtiene detalle de tarjetas de crédito: saldo actual, pagos realizados, cuota de manejo, día de corte y pago mínimo si está configurado.",
    parameters: {
      type: "object",
      properties: {
        card_name: { type: "string", description: "Nombre/alias de la tarjeta (opcional). Si no se especifica, devuelve todas." },
      },
      required: [],
    },
  },
  {
    name: "get_receivables",
    description: "Obtiene cuentas por cobrar activas (lo que le deben al usuario) con detalle de pagos recibidos y saldo pendiente.",
    parameters: { type: "object", properties: {}, required: [] },
  },
  {
    name: "get_upcoming_payments",
    description: "Obtiene pagos próximos: pagos automáticos, mínimos de tarjetas y cuotas de deudas que vencen pronto.",
    parameters: {
      type: "object",
      properties: {
        days: { type: "number", description: "Cantidad de días hacia adelante. Default: 30." },
      },
      required: [],
    },
  },
  {
    name: "get_payment_methods",
    description: "Obtiene los métodos de pago disponibles del usuario (tarjetas de crédito y métodos de pago). Útil cuando necesitas saber qué opciones tiene el usuario para registrar un gasto.",
    parameters: { type: "object", properties: {}, required: [] },
  },
  {
    name: "register_expense",
    description: "Registra un gasto. Si falta payment_type o payment_ref, devuelve action_required para que el usuario elija entre opciones. La fecha por defecto es hoy.",
    parameters: {
      type: "object",
      properties: {
        amount: { type: "number", description: "Monto del gasto." },
        description: { type: "string", description: "Descripción del gasto." },
        date: { type: "string", description: "Fecha del gasto ISO (YYYY-MM-DD). Default: hoy." },
      },
      required: ["amount", "description"],
    },
  },
  {
    name: "register_debt",
    description: "Registra una deuda (compra a cuotas).",
    parameters: {
      type: "object",
      properties: {
        name: { type: "string", description: "Nombre o concepto de la deuda." },
        total_amount: { type: "number", description: "Monto total de la deuda." },
        number_of_installments: { type: "number", description: "Cantidad de cuotas." },
        due_date: { type: "string", description: "Fecha de vencimiento ISO (YYYY-MM-DD)." },
      },
      required: ["name", "total_amount", "number_of_installments", "due_date"],
    },
  },
  {
    name: "register_receivable",
    description: "Registra una cuenta por cobrar (algo que le deben al usuario).",
    parameters: {
      type: "object",
      properties: {
        debtor_name: { type: "string", description: "Nombre del deudor." },
        total_amount: { type: "number", description: "Monto total." },
        description: { type: "string", description: "Descripción opcional." },
        due_date: { type: "string", description: "Fecha de vencimiento ISO (YYYY-MM-DD). Opcional." },
      },
      required: ["debtor_name", "total_amount"],
    },
  },
  {
    name: "register_payment",
    description: "Registra un pago a una deuda existente.",
    parameters: {
      type: "object",
      properties: {
        debt_id: { type: "string", description: "ID de la deuda." },
        amount: { type: "number", description: "Monto del pago." },
        date: { type: "string", description: "Fecha del pago ISO (YYYY-MM-DD). Default: hoy." },
      },
      required: ["debt_id", "amount"],
    },
  },
];

// ─── Helpers ────────────────────────────────────────────────────────────────

const OR_API = "https://openrouter.ai/api/v1/chat/completions";
const OR_MODEL = "nvidia/nemotron-3-ultra-550b-a55b:free";

type Message = {
  role: "system" | "user" | "assistant" | "tool";
  content: string;
  tool_calls?: ToolCall[];
  tool_call_id?: string;
  name?: string;
};

type ToolCall = {
  id: string;
  type: "function";
  function: { name: string; arguments: string };
};

type SSEMessage =
  | { type: "content"; text: string; done: boolean }
  | { type: "error"; text: string }
  | { type: "action_required"; prompt: string; options: Array<{ label: string; value: string }> };

function sse(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

function copFormat(n: number): string {
  return new Intl.NumberFormat("es-CO", {
    style: "currency",
    currency: "COP",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(n);
}

function todayDate(): string {
  return new Date().toISOString().slice(0, 10);
}

function firstOfMonth(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-01`;
}

function firstOfNextMonth(): string {
  const d = new Date();
  d.setMonth(d.getMonth() + 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-01`;
}

// ─── Agent system prompts ────────────────────────────────────────────────────

const SYSTEM_PROMPTS: Record<string, string> = {
  financialAdvisor: `Eres un asesor financiero experto de Perfinance. Ayudas al usuario a entender y mejorar sus finanzas con SUS DATOS REALES.

CONTEXTO DE LA APP:
Perfinance es una app de EGRESOS. El usuario registra:
- Gastos (con fecha, monto, descripción, método de pago)
- Pagos a tarjetas de crédito (monto pagado a cada tarjeta)
- Pagos a deudas (cuotas que va pagando)
- Cuentas por cobrar (le deben dinero)
- Pagos automáticos

NO existen en el sistema: tasas de interés, saldo actual de tarjetas, pago mínimo, ni límites de crédito. Esas son cosas que el banco maneja externamente.

REGLAS:
- Responde MÁXIMO en 3-4 oraciones. Sé directo y conciso.
- NUNCA menciones nombres de funciones, tools, o técnicismos internos.
- Trabaja con los datos que SÍ tienes: gastos, pagos a tarjetas, pagos a deudas.
- Si el usuario pregunta sobre algo que no tienes (ej: "cuánto debo en la tarjeta"), explica que solo registras los pagos, no los saldos del banco.
- Puedes dar insights sobre: patrones de gasto, comparación entre meses, en cuánto tarjeta/pago se va más dinero, tendencias.
- Siempre llama get_financial_summary() primero para contexto.

FORMATO: Solo texto plano o negritas. NO uses tablas, headers (#), ni listas largas.

TONO: Español colombiano neutro, tratando al usuario de tú (tienes, puedes, dime). Nunca uses voseo. Amigable pero directo, como un colega experto.`,

  appAssistant: `Eres el asistente de Perfinance. Ayudas a registrar y gestionar datos: gastos, pagos a tarjetas, pagos a deudas, cuentas por cobrar, pagos automáticos.

REGLAS:
- Responde MÁXIMO en 2-3 oraciones. Sé breve.
- NUNCA menciones nombres de funciones o tools al usuario.
- Si falta info clave para registrar algo, pregunta directamente.
- Para consultas, muestra los datos simples.

FORMATO: Solo texto plano o negritas. NO tablas, headers ni listas largas.

TONO: Español colombiano neutro, tratando al usuario de tú; nunca voseo. Directo y rápido.`,

  ephemeralChat: `Eres un asistente rápido y directo de Perfinance. Respondes preguntas generales, das consejos financieros breves, o resuelves dudas del usuario.

NO tienes acceso a los datos financieros del usuario. Solo conversas.

Sé breve y directo. Habla en español colombiano neutro y trata al usuario de tú (tienes, puedes, dime). Nunca uses voseo. Si el usuario pregunta sobre sus finanzas, dile que use el Asesor o el Asistente para consultas con datos reales.`,
};

// Tools available per agent type
const ADVISOR_TOOLS = TOOLS; // all tools
const ASSISTANT_TOOLS = TOOLS.filter((t) =>
  ["get_financial_summary", "get_expenses", "get_debt_details", "get_card_details", "get_receivables", "get_upcoming_payments", "get_payment_methods", "register_expense", "register_debt", "register_receivable", "register_payment"].includes(t.name)
);
const EPHEMERAL_TOOLS: typeof TOOLS = []; // no tools — general chat only

function getToolsForAgent(agentType: string): typeof TOOLS {
  switch (agentType) {
    case "appAssistant": return ASSISTANT_TOOLS;
    case "ephemeralChat": return EPHEMERAL_TOOLS;
    default: return ADVISOR_TOOLS;
  }
}

function getSystemPrompt(agentType: string): string {
  return SYSTEM_PROMPTS[agentType] ?? SYSTEM_PROMPTS.financialAdvisor;
}

// ─── DB Query functions ─────────────────────────────────────────────────────

async function getFinancialSummary(supabase: ReturnType<typeof createClient>, userId: string) {
  const now = todayDate();
  const monthStart = firstOfMonth();
  const prevMonthStart = new Date();
  prevMonthStart.setMonth(prevMonthStart.getMonth() - 1);
  const prevMonthStartStr = `${prevMonthStart.getFullYear()}-${String(prevMonthStart.getMonth() + 1).padStart(2, "0")}-01`;
  const prevMonthEnd = new Date(prevMonthStart.getFullYear(), prevMonthStart.getMonth() + 1, 0);
  const prevMonthEndStr = `${prevMonthEnd.getFullYear()}-${String(prevMonthEnd.getMonth() + 1).padStart(2, "0")}-${String(prevMonthEnd.getDate()).padStart(2, "0")}`;

  const [expCurrent, expPrev, debts, cards, payments, receivables, autopay] = await Promise.all([
    supabase.from("expenses").select("amount").gte("date", monthStart).lte("date", now),
    supabase.from("expenses").select("amount").gte("date", prevMonthStartStr).lte("date", prevMonthEndStr),
    supabase.from("debts").select("id, name, total_amount, status").eq("status", "active"),
    supabase.from("credit_cards").select("id, alias"),
    supabase.from("card_payments").select("card_id, amount, date").gte("date", monthStart).lte("date", now),
    supabase.from("receivables").select("id, debtor_name, total_amount, status").eq("status", "active"),
    supabase.from("automatic_payments").select("description, amount, next_run_date, frequency").eq("status", "active").gte("next_run_date", now).order("next_run_date").limit(5),
  ]);

  const totalThisMonth = (expCurrent.data ?? []).reduce((s: number, r: { amount: number }) => s + Number(r.amount), 0);
  const totalPrevMonth = (expPrev.data ?? []).reduce((s: number, r: { amount: number }) => s + Number(r.amount), 0);

  const activeDebts = debts.data ?? [];
  const allCards = cards.data ?? [];
  const allPayments = payments.data ?? [];

  const cardDebtMap = new Map<string, number>();
  for (const c of allCards) cardDebtMap.set(c.id, 0);
  for (const p of allPayments) {
    cardDebtMap.set(p.card_id, (cardDebtMap.get(p.card_id) ?? 0) + Number(p.amount));
  }

  return {
    total_expenses_this_month: totalThisMonth,
    total_expenses_previous_month: totalPrevMonth,
    expense_vs_last_month_pct: totalPrevMonth > 0 ? Math.round((totalThisMonth - totalPrevMonth) / totalPrevMonth * 100) : null,
    active_debts_count: activeDebts.length,
    cards: allCards.map((c: { id: string; alias: string }) => ({
      alias: c.alias,
      paid_this_month: cardDebtMap.get(c.id) ?? 0,
    })),
    upcoming_automatic_payments: autopay.data ?? [],
    active_receivables_count: (receivables.data ?? []).length,
  };
}

async function getExpenses(supabase: ReturnType<typeof createClient>, userId: string, params: { from_date?: string; to_date?: string; query?: string }) {
  let query = supabase
    .from("expenses")
    .select("id, amount, date, payment_type, payment_ref, description")
    .gte("date", params.from_date ?? firstOfMonth())
    .lte("date", params.to_date ?? todayDate())
    .order("date", { ascending: false });

  if (params.query) {
    query = query.ilike("description", `%${params.query}%`);
  }

  const { data } = await query;
  const rows = (data ?? []) as Array<{ id: string; amount: number; date: string; payment_type: string; payment_ref: string; description: string | null }>;

  const [cards, methods] = await Promise.all([
    supabase.from("credit_cards").select("id, alias"),
    supabase.from("payment_methods").select("id, name"),
  ]);

  const cardMap = new Map((cards.data ?? []).map((c: { id: string; alias: string }) => [c.id, c.alias]));
  const methodMap = new Map((methods.data ?? []).map((m: { id: string; name: string }) => [m.id, m.name]));

  const total = rows.reduce((s: number, r) => s + Number(r.amount), 0);

  return {
    total,
    count: rows.length,
    expenses: rows.map((r) => ({
      amount: r.amount,
      date: r.date,
      description: r.description ?? "",
      payment_label: r.payment_type === "credit_card" ? (cardMap.get(r.payment_ref) ?? "Tarjeta") : (methodMap.get(r.payment_ref) ?? "Método"),
    })),
  };
}

async function getSpendingDiff(supabase: ReturnType<typeof createClient>, userId: string, params: { period_a_from: string; period_a_to: string; period_b_from?: string; period_b_to?: string }) {
  const pbFrom = params.period_b_from ?? params.period_a_from; // same as A start
  // default B to same duration as A, ending today
  const aDuration = new Date(params.period_a_to).getTime() - new Date(params.period_a_from).getTime();
  const defaultBFrom = new Date(new Date(params.period_a_from).getTime() - aDuration);
  const pbTo = params.period_b_to ?? todayDate();
  const pbFromActual = params.period_b_from ?? defaultBFrom.toISOString().slice(0, 10);

  const [periodA, periodB, cards, methods] = await Promise.all([
    supabase.from("expenses").select("amount, payment_type, payment_ref, description").gte("date", params.period_a_from).lte("date", params.period_a_to),
    supabase.from("expenses").select("amount, payment_type, payment_ref, description").gte("date", pbFromActual).lte("date", pbTo),
    supabase.from("credit_cards").select("id, alias"),
    supabase.from("payment_methods").select("id, name"),
  ]);

  const cardMap = new Map((cards.data ?? []).map((c: { id: string; alias: string }) => [c.id, c.alias]));
  const methodMap = new Map((methods.data ?? []).map((m: { id: string; name: string }) => [m.id, m.name]));

  const totalA = (periodA.data ?? []).reduce((s: number, r: { amount: number }) => s + Number(r.amount), 0);
  const totalB = (periodB.data ?? []).reduce((s: number, r: { amount: number }) => s + Number(r.amount), 0);
  const diff = totalB - totalA;
  const pctChange = totalA > 0 ? Math.round(diff / totalA * 100) : null;

  function breakdown(rows: Array<{ payment_type: string; payment_ref: string; amount: number }>) {
    const map = new Map<string, number>();
    for (const r of rows) {
      const label = r.payment_type === "credit_card" ? (cardMap.get(r.payment_ref) ?? "Tarjeta") : (methodMap.get(r.payment_ref) ?? "Método");
      map.set(label, (map.get(label) ?? 0) + Number(r.amount));
    }
    return [...map.entries()].map(([label, total]) => ({ label, total }));
  }

  return {
    period_a: { from: params.period_a_from, to: params.period_a_to, total: totalA, breakdown: breakdown(periodA.data ?? []) },
    period_b: { from: pbFromActual, to: pbTo, total: totalB, breakdown: breakdown(periodB.data ?? []) },
    difference: diff,
    percentage_change: pctChange,
  };
}

async function getDebtDetails(supabase: ReturnType<typeof createClient>, userId: string) {
  const { data: debts } = await supabase
    .from("debts")
    .select("id, name, total_amount, number_of_installments, due_date, status")
    .eq("status", "active");

  const debtList = (debts ?? []) as Array<{ id: string; name: string; total_amount: number; number_of_installments: number; due_date: string; status: string }>;

  const result = [];
  for (const d of debtList) {
    const { data: payments } = await supabase
      .from("debt_payments")
      .select("amount")
      .eq("debt_id", d.id);

    const paidTotal = (payments ?? []).reduce((s: number, p: { amount: number }) => s + Number(p.amount), 0);
    const installmentAmt = d.total_amount / d.number_of_installments;
    const paidInstallments = Math.floor(paidTotal / installmentAmt);

    result.push({
      id: d.id,
      name: d.name,
      total_amount: d.total_amount,
      amount_per_installment: installmentAmt,
      number_of_installments: d.number_of_installments,
      paid_installments: paidInstallments,
      remaining_installments: d.number_of_installments - paidInstallments,
      paid_amount: paidTotal,
      remaining_amount: d.total_amount - paidTotal,
      due_date: d.due_date,
    });
  }

  return { debts: result };
}

async function getCardDetails(supabase: ReturnType<typeof createClient>, userId: string, params: { card_name?: string }) {
  let query = supabase.from("credit_cards").select("id, alias, cut_off_day, management_fee, is_active");
  const allCards = (await query).data ?? [];

  let filteredCards = allCards as Array<{ id: string; alias: string; cut_off_day: number; management_fee: number; is_active: boolean }>;
  if (params.card_name) {
    filteredCards = filteredCards.filter((c) => c.alias.toLowerCase().includes(params.card_name!.toLowerCase()));
  }

  const result = [];
  const now = todayDate();
  const monthStart = firstOfMonth();
  for (const c of filteredCards) {
    const [expenses, payments, minPayments] = await Promise.all([
      supabase.from("expenses").select("amount").eq("payment_type", "credit_card").eq("payment_ref", c.id).gte("date", monthStart).lte("date", now),
      supabase.from("card_payments").select("amount").eq("card_id", c.id).gte("date", monthStart).lte("date", now),
      supabase.from("min_payment_configs").select("amount, year, month").eq("card_id", c.id).order("year", { ascending: false }).order("month", { ascending: false }).limit(1),
    ]);

    const totalSpending = (expenses.data ?? []).reduce((s: number, r: { amount: number }) => s + Number(r.amount), 0);
    const totalPayments = (payments.data ?? []).reduce((s: number, r: { amount: number }) => s + Number(r.amount), 0);
    const minPayment = (minPayments.data ?? [])[0] as { amount: number; year: number; month: number } | undefined;

    result.push({
      alias: c.alias,
      cut_off_day: c.cut_off_day,
      management_fee: c.management_fee,
      is_active: c.is_active,
      total_spending: totalSpending,
      total_payments: totalPayments,
      current_debt: totalSpending - totalPayments,
      min_payment: minPayment ? { amount: minPayment.amount, month: minPayment.month, year: minPayment.year } : null,
    });
  }

  return { cards: result };
}

async function getReceivables(supabase: ReturnType<typeof createClient>, userId: string) {
  const { data: receivables } = await supabase
    .from("receivables")
    .select("id, debtor_name, total_amount, description, due_date, status")
    .eq("status", "active");

  const recvList = (receivables ?? []) as Array<{ id: string; debtor_name: string; total_amount: number; description: string | null; due_date: string | null; status: string }>;

  const result = [];
  for (const r of recvList) {
    const { data: payments } = await supabase
      .from("receivable_payments")
      .select("amount")
      .eq("receivable_id", r.id);

    const paidTotal = (payments ?? []).reduce((s: number, p: { amount: number }) => s + Number(p.amount), 0);

    result.push({
      debtor_name: r.debtor_name,
      total_amount: r.total_amount,
      description: r.description,
      due_date: r.due_date,
      paid_amount: paidTotal,
      remaining_amount: r.total_amount - paidTotal,
    });
  }

  return { receivables: result };
}

async function getUpcomingPayments(supabase: ReturnType<typeof createClient>, userId: string, params: { days?: number }) {
  const days = params.days ?? 30;
  const now = todayDate();
  const future = new Date();
  future.setDate(future.getDate() + days);
  const futureStr = future.toISOString().slice(0, 10);

  const [automatic, debts, cards] = await Promise.all([
    supabase.from("automatic_payments").select("id, description, amount, next_run_date, frequency, payment_type, payment_ref").eq("status", "active").gte("next_run_date", now).lte("next_run_date", futureStr).order("next_run_date").limit(20),
    supabase.from("debts").select("id, name, total_amount, number_of_installments, due_date").eq("status", "active").gte("due_date", now).lte("due_date", futureStr).order("due_date").limit(20),
    supabase.from("credit_cards").select("id, alias, cut_off_day"),
  ]);

  return {
    automatic_payments: (automatic.data ?? []).map((p: { description: string; amount: number; next_run_date: string; frequency: string }) => ({
      description: p.description,
      amount: p.amount,
      next_run_date: p.next_run_date,
      frequency: p.frequency,
    })),
    debts_due: (debts.data ?? []).map((d: { name: string; total_amount: number; number_of_installments: number; due_date: string }) => ({
      name: d.name,
      total_amount: d.total_amount,
      installment_amount: d.total_amount / d.number_of_installments,
      due_date: d.due_date,
    })),
    cards_with_upcoming_cut: (cards.data ?? []).filter(() => true).slice(0, 10),
  };
}

async function getPaymentMethods(supabase: ReturnType<typeof createClient>, userId: string) {
  const [cards, methods] = await Promise.all([
    supabase.from("credit_cards").select("id, alias").eq("is_active", true),
    supabase.from("payment_methods").select("id, name").order("name"),
  ]);

  return {
    credit_cards: (cards.data ?? []).map((c: { id: string; alias: string }) => ({ id: c.id, label: c.alias })),
    payment_methods: (methods.data ?? []).map((m: { id: string; name: string }) => ({ id: m.id, label: m.name })),
  };
}

// ─── Tool dispatcher ────────────────────────────────────────────────────────

type ToolResult = { result?: unknown; actionRequired?: SSEMessage };

async function executeTool(supabase: ReturnType<typeof createClient>, userId: string, name: string, args: Record<string, unknown>): Promise<ToolResult> {
  switch (name) {
    case "get_financial_summary":
      return { result: await getFinancialSummary(supabase, userId) };
    case "get_expenses":
      return { result: await getExpenses(supabase, userId, args as { from_date?: string; to_date?: string; query?: string }) };
    case "get_spending_diff":
      return { result: await getSpendingDiff(supabase, userId, args as { period_a_from: string; period_a_to: string; period_b_from?: string; period_b_to?: string }) };
    case "get_debt_details":
      return { result: await getDebtDetails(supabase, userId) };
    case "get_card_details":
      return { result: await getCardDetails(supabase, userId, args as { card_name?: string }) };
    case "get_receivables":
      return { result: await getReceivables(supabase, userId) };
    case "get_upcoming_payments":
      return { result: await getUpcomingPayments(supabase, userId, args as { days?: number }) };
    case "get_payment_methods":
      return { result: await getPaymentMethods(supabase, userId) };
    case "register_expense": {
      const { amount, description, date } = args as { amount: number; description: string; date?: string };
      if (!amount || !description) {
        return { result: { error: "Faltan datos: amount y description son requeridos." } };
      }
      // Need to ask for payment method
      const methods = await getPaymentMethods(supabase, userId);
      const allOptions = [
        ...methods.credit_cards.map((c: { id: string; label: string }) => ({ label: `💳 ${c.label} (tarjeta)`, value: `credit_card:${c.id}` })),
        ...methods.payment_methods.map((m: { id: string; label: string }) => ({ label: `💰 ${m.label} (efectivo/cuenta)`, value: `payment_method:${m.id}` })),
      ];

      return {
        actionRequired: {
          type: "action_required",
          prompt: `Para registrar el gasto de ${copFormat(amount)} en "${description}"${date ? ` del ${date}` : " de hoy"}, ¿con qué medio de pago lo haces?`,
          options: allOptions,
        },
        result: { pending_expense: { amount, description, date: date ?? todayDate() } },
      };
    }
    case "register_debt": {
      const { name: debtName, total_amount, number_of_installments, due_date } = args as { name: string; total_amount: number; number_of_installments: number; due_date: string };
      if (!debtName || !total_amount || !number_of_installments || !due_date) {
        return { result: { error: "Faltan datos requeridos para registrar la deuda." } };
      }
      const { error } = await supabase.from("debts").insert({
        name: debtName,
        total_amount,
        number_of_installments,
        due_date,
      });
      if (error) return { result: { error: error.message } };
      return { result: { success: true, message: `Deuda "${debtName}" registrada por ${copFormat(total_amount)} en ${number_of_installments} cuotas, vence ${due_date}.` } };
    }
    case "register_receivable": {
      const { debtor_name, total_amount: rAmount, description: rDesc, due_date: rDue } = args as { debtor_name: string; total_amount: number; description?: string; due_date?: string };
      if (!debtor_name || !rAmount) {
        return { result: { error: "Faltan datos: debtor_name y total_amount son requeridos." } };
      }
      const { error } = await supabase.from("receivables").insert({
        debtor_name,
        total_amount: rAmount,
        description: rDesc ?? null,
        due_date: rDue ?? null,
      });
      if (error) return { result: { error: error.message } };
      return { result: { success: true, message: `Cuenta por cobrar a ${debtor_name} por ${copFormat(rAmount)} registrada.` } };
    }
    case "register_payment": {
      const { debt_id, amount: pAmount, date: pDate } = args as { debt_id: string; amount: number; date?: string };
      if (!debt_id || !pAmount) {
        return { result: { error: "Faltan datos: debt_id y amount son requeridos." } };
      }
      const { error } = await supabase.from("debt_payments").insert({
        debt_id,
        amount: pAmount,
        date: pDate ?? todayDate(),
      });
      if (error) return { result: { error: error.message } };
      return { result: { success: true, message: `Pago de ${copFormat(pAmount)} registrado correctamente.` } };
    }
    default:
      return { result: { error: `Tool desconocida: ${name}` } };
  }
}

// ─── OpenRouter call (streaming) ────────────────────────────────────────────

async function callOpenRouter(
  messages: Message[],
  tools: typeof TOOLS,
  onChunk: (text: string) => void,
): Promise<{ finishReason: string; message: Message; toolCalls: ToolCall[] }> {
  const body: Record<string, unknown> = {
    model: OR_MODEL,
    messages,
    tools: tools.map((t) => ({
      type: "function" as const,
      function: t,
    })),
    stream: true,
    max_tokens: 4096,
    temperature: 0.3,
  };

  const response = await fetch(OR_API, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get("OPENROUTER_API_KEY")!}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://perfinance.app",
      "X-Title": "Perfinance",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OpenRouter error ${response.status}: ${text}`);
  }

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let collectedContent = "";
  let finishReason = "";
  const toolCalls: ToolCall[] = [];

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || !trimmed.startsWith("data: ")) continue;
      const jsonStr = trimmed.slice(6);
      if (jsonStr === "[DONE]") break;

      try {
        const chunk = JSON.parse(jsonStr);
        const delta = chunk.choices?.[0]?.delta;
        const finish = chunk.choices?.[0]?.finish_reason;

        if (finish) finishReason = finish;

        if (delta?.content) {
          collectedContent += delta.content;
          onChunk(delta.content);
        }

        if (delta?.tool_calls) {
          for (const tc of delta.tool_calls) {
            const idx = tc.index ?? 0;
            if (!toolCalls[idx]) {
              toolCalls[idx] = { id: tc.id ?? "", type: "function", function: { name: "", arguments: "" } };
            }
            if (tc.id) toolCalls[idx].id = tc.id;
            if (tc.function?.name) toolCalls[idx].function.name += tc.function.name;
            if (tc.function?.arguments) toolCalls[idx].function.arguments += tc.function.arguments;
          }
        }
      } catch {
        // skip malformed chunks
      }
    }
  }

  return {
    finishReason,
    message: { role: "assistant", content: collectedContent, tool_calls: toolCalls.length > 0 ? toolCalls : undefined },
    toolCalls,
  };
}

// ─── Main handler ───────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { "Content-Type": "application/json" } });
  }

  // Interruptor del asesor: la app lo tiene deshabilitado (advisorEnabled en
  // lib/core/config/features.dart). Mientras el secret ADVISOR_ENABLED no sea
  // "true", la función no lee datos ni llama a OpenRouter, aunque alguien la
  // invoque directo (por ejemplo, un APK viejo).
  if (Deno.env.get("ADVISOR_ENABLED") !== "true") {
    return new Response(JSON.stringify({ error: "Advisor disabled" }), { status: 403, headers: { "Content-Type": "application/json" } });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }

  const body: { message: string; history?: Message[]; agent_type?: string } = await req.json();
  if (!body.message) {
    return new Response(JSON.stringify({ error: "message is required" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  const agentType = body.agent_type ?? "financialAdvisor";
  const agentTools = getToolsForAgent(agentType);
  const systemPrompt = getSystemPrompt(agentType);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const jwtToken = authHeader.replace(/^Bearer\s+/i, "");
  const { data: { user }, error: userError } = await supabase.auth.getUser(jwtToken);
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Invalid session" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }

  const userId = user.id;
  const history = body.history ?? [];

  // ── Build SSE response ──

  const stream = new ReadableStream({
    async start(controller) {
      const enqueue = (event: string, data: unknown) => {
        controller.enqueue(new TextEncoder().encode(sse(event, data)));
      };

      try {
        let messages: Message[] = [
          { role: "system", content: systemPrompt },
          ...history,
          { role: "user", content: body.message },
        ];

        // Multi-round tool calling loop (max 5 rounds, skip if no tools)
        const maxRounds = agentTools.length > 0 ? 5 : 1;
        for (let round = 0; round < maxRounds; round++) {
          let currentContent = "";

          const onChunk = (text: string) => {
            currentContent += text;
            enqueue("content", { type: "content", text, done: false });
          };

          const { finishReason, message, toolCalls } = await callOpenRouter(messages, agentTools, onChunk);

          enqueue("content", { type: "content", text: "", done: true });

          if (toolCalls.length > 0) {
            messages.push(message);

            for (const tc of toolCalls) {
              let args: Record<string, unknown> = {};
              try {
                args = JSON.parse(tc.function.arguments);
              } catch {
                args = {};
              }

              const { result, actionRequired } = await executeTool(supabase, userId, tc.function.name, args);

              if (actionRequired) {
                enqueue("action_required", actionRequired);
                controller.close();
                return;
              }

              messages.push({
                role: "tool",
                tool_call_id: tc.id,
                name: tc.function.name,
                content: JSON.stringify(result),
              });
            }

            // Continue loop — model will respond with text after tool results
            continue;
          }

          // No tool calls → final response
          break;
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : "Unknown error";
        enqueue("error", { type: "error", text: msg });
      } finally {
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
      "Access-Control-Allow-Origin": "*",
    },
  });
});
