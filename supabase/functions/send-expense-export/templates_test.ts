import { assert } from "jsr:@std/assert@1";
import { buildExportEmail } from "./templates.ts";

Deno.test("exportación: total como denominación, palabras de la app, sin esquema técnico", () => {
  const email = buildExportEmail({ periodLabel: "Octubre-Noviembre 2026", rowCount: 5, total: 234295 });
  assert(email.html.includes("$ 234.295"));
  assert(email.html.includes("Octubre-Noviembre 2026"));
  assert(email.text.includes("Egresos: 5"));
  assert(!email.html.includes("DESCRIPCION"), "el esquema de columnas no es texto para el usuario");
  assert(!email.html.includes("Movimientos"));
  assert(!email.html.includes("linear-gradient"));
});

Deno.test("exportación: un solo egreso en singular", () => {
  const email = buildExportEmail({ periodLabel: "Noviembre 2026", rowCount: 1, total: 12000 });
  assert(email.text.includes("Egresos: 1"));
  assert(email.text.includes("1 egreso"));
});
