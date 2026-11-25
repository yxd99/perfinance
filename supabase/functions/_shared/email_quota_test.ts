import { assertEquals } from "jsr:@std/assert@1";
import { quotaExceededMessage } from "./email_quota.ts";

Deno.test("quotaExceededMessage: nombra el tope y el primer día del mes siguiente en Colombia", () => {
  // 24 nov 2026, 20:00 en Bogotá (UTC-5).
  assertEquals(
    quotaExceededMessage(10, new Date("2026-11-25T01:00:00Z")),
    "Llegaste al límite de 10 correos de este mes. Podrás enviar más desde el 1 de diciembre.",
  );
});

Deno.test("quotaExceededMessage: en diciembre el mes siguiente es enero", () => {
  assertEquals(
    quotaExceededMessage(3, new Date("2026-12-15T12:00:00Z")),
    "Llegaste al límite de 3 correos de este mes. Podrás enviar más desde el 1 de enero.",
  );
});

Deno.test("quotaExceededMessage: usa la hora de Colombia, no la UTC", () => {
  // 1 dic 2026 03:00 UTC = 30 nov 2026 22:00 en Bogotá: todavía es noviembre.
  assertEquals(
    quotaExceededMessage(10, new Date("2026-12-01T03:00:00Z")),
    "Llegaste al límite de 10 correos de este mes. Podrás enviar más desde el 1 de diciembre.",
  );
});

Deno.test("quotaExceededMessage: tope de 1 en singular", () => {
  assertEquals(
    quotaExceededMessage(1, new Date("2026-11-25T01:00:00Z")),
    "Llegaste al límite de 1 correo de este mes. Podrás enviar más desde el 1 de diciembre.",
  );
});
