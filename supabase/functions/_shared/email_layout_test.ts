import { assert, assertEquals } from "jsr:@std/assert@1";
import { type EmailContent, fromWithDisplayName, renderEmail, renderPlainText } from "./email_layout.ts";

const sample: EmailContent = {
  title: "Prueba",
  preheader: "Te falta por pagar $ 250.000",
  note: { label: "Te falta por pagar", amount: "$ 250.000" },
  heading: "Ana registró tu pago",
  intro: ["Hola <Juan>, todo bien."],
  rows: [{ label: "Deuda total", value: "$ 400.000", strong: true }],
  footer: ["Recibes este correo porque Ana registró esta deuda."],
};

Deno.test("renderEmail: colores sólidos con respaldo, sin degradados, sombras ni emoji", () => {
  const html = renderEmail(sample);
  assert(html.includes('bgcolor="#5B3A7A"'), "la franja morada necesita bgcolor para Outlook");
  assert(!html.includes("linear-gradient"));
  assert(!html.includes("box-shadow"));
  assert(!html.includes("✓"));
  assert(html.includes('content="light only"'), "evita que el modo oscuro invierta los colores");
});

Deno.test("renderEmail: escapa el texto y lleva preheader oculto", () => {
  const html = renderEmail(sample);
  assert(html.includes("Hola &lt;Juan&gt;, todo bien."));
  assert(!html.includes("<Juan>"));
  assert(html.includes("display:none") && html.includes("Te falta por pagar $ 250.000"));
});

Deno.test("renderEmail: el sello solo aparece cuando se pide", () => {
  assert(!renderEmail(sample).includes("Saldada"));
  assert(renderEmail({ ...sample, note: { ...sample.note, stamp: "Saldada" } }).includes("Saldada"));
});

Deno.test("renderPlainText: mismo contenido en texto", () => {
  const text = renderPlainText(sample);
  assert(text.startsWith("Te falta por pagar: $ 250.000"));
  assert(text.includes("Deuda total: $ 400.000"));
  assert(text.includes("Hola <Juan>, todo bien."));
  assert(text.includes("Recibes este correo porque Ana registró esta deuda."));
});

Deno.test("fromWithDisplayName: conserva la dirección de MAIL_FROM", () => {
  assertEquals(
    fromWithDisplayName("Perfinance <hola@perfinance.dev>", "Ana vía Perfinance"),
    "Ana vía Perfinance <hola@perfinance.dev>",
  );
  assertEquals(fromWithDisplayName("hola@perfinance.dev", "Ana vía Perfinance"), "Ana vía Perfinance <hola@perfinance.dev>");
  assertEquals(
    fromWithDisplayName("Perfinance <hola@perfinance.dev>", 'Ana "<x>"\r\nBcc: a@b.co'),
    "Ana x Bcc: a@b.co <hola@perfinance.dev>",
  );
});
