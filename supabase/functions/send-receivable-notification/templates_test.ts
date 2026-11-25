import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildNotificationEmail, type NotificationInput } from "./templates.ts";

const base: NotificationInput = {
  event: "created",
  debtorName: "Juan Pérez",
  description: "Préstamo para el carro",
  totalAmount: 400000,
  remainingBalance: 400000,
  creditorName: "Ana Gómez",
  creditorEmail: "ana@gmail.com",
  isRegistered: false,
};

Deno.test("recordatorio: nombra a quien cobra en el asunto y en el texto", () => {
  const email = buildNotificationEmail({ ...base, event: "reminder", remainingBalance: 250000 });
  assertEquals(email.subject, "Recordatorio de Ana Gómez: tienes un saldo pendiente");
  assert(email.html.includes("Ana Gómez te recuerda"));
  assert(email.text.includes("Te falta por pagar: $ 250.000"));
});

Deno.test("deuda nueva: muestra el total y no usa palabras de quien cobra", () => {
  const email = buildNotificationEmail(base);
  assertEquals(email.subject, "Ana Gómez registró una deuda contigo");
  assert(email.html.includes("$ 400.000"));
  assert(email.html.includes("Préstamo para el carro"));
  assert(!/cobro/i.test(email.html), "el deudor no hizo un cobro");
  assert(!email.html.includes("en tu cuenta"));
});

Deno.test("pago registrado: dice el pago y lo que falta", () => {
  const email = buildNotificationEmail({
    ...base,
    event: "payment_recorded",
    remainingBalance: 250000,
    paymentAmount: 150000,
    paymentDate: "2026-11-20T00:00:00Z",
  });
  assertEquals(email.subject, "Ana Gómez registró tu pago de $ 150.000");
  assert(email.text.includes("Pago: $ 150.000"));
  assert(email.text.includes("Fecha del pago: 20 de noviembre de 2026"));
  assert(email.text.startsWith("Te falta por pagar: $ 250.000"));
});

Deno.test("deuda saldada: sello y asunto propios, sin ✓", () => {
  const email = buildNotificationEmail({
    ...base,
    event: "payment_recorded",
    remainingBalance: 0,
    paymentAmount: 400000,
    paymentDate: "2026-11-24T00:00:00Z",
  });
  assertEquals(email.subject, "Saldaste tu deuda con Ana Gómez");
  assert(email.html.includes("Saldada"));
  assert(!email.html.includes("✓"));
});

Deno.test("pago editado y eliminado tienen su propio asunto", () => {
  const edited = buildNotificationEmail({ ...base, event: "payment_edited", paymentAmount: 100000, paymentDate: "2026-11-20T00:00:00Z", remainingBalance: 300000 });
  assertEquals(edited.subject, "Ana Gómez corrigió un pago tuyo");
  const deleted = buildNotificationEmail({ ...base, event: "payment_deleted", paymentAmount: 150000, paymentDate: "2026-11-20T00:00:00Z" });
  assertEquals(deleted.subject, "Ana Gómez eliminó un pago de tu deuda");
  assert(deleted.text.includes("Pago eliminado: $ 150.000"));
});

Deno.test("sin nombre usa el correo de quien cobra", () => {
  const email = buildNotificationEmail({ ...base, creditorName: "  " });
  assertEquals(email.subject, "ana@gmail.com registró una deuda contigo");
  assertEquals(email.fromName, "ana@gmail.com vía Perfinance");
});

Deno.test("el pie explica qué es Perfinance y qué hacer si no reconoces la deuda", () => {
  const email = buildNotificationEmail(base);
  assert(email.text.includes("una app para llevar las cuentas personales"));
  assert(email.text.includes("Si no reconoces esta deuda"));
  assert(email.text.includes("ana@gmail.com"));
  assertEquals(email.fromName, "Ana Gómez vía Perfinance");
});

Deno.test("a un deudor registrado le dice dónde verla en la app", () => {
  assert(buildNotificationEmail({ ...base, isRegistered: true }).text.includes("en la sección Deudas"));
  assert(!buildNotificationEmail(base).text.includes("en la sección Deudas"));
});

Deno.test("escapa nombres y descripciones", () => {
  const email = buildNotificationEmail({ ...base, debtorName: "<b>Juan</b>", description: '"><img src=x>' });
  assert(!email.html.includes("<b>Juan</b>"));
  assert(!email.html.includes("<img src=x>"));
});
