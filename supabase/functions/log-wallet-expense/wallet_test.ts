import { assertEquals } from "jsr:@std/assert@1";
import {
  cardKey,
  localWallTimestamp,
  matchTarget,
  parseAmount,
  resolveTarget,
  type Target,
} from "./wallet.ts";

Deno.test("parseAmount: número directo", () => {
  assertEquals(parseAmount(25900), 25900);
  assertEquals(parseAmount(12.5), 12.5);
});

Deno.test("parseAmount: texto con símbolo y separador de miles", () => {
  assertEquals(parseAmount("$25.900"), 25900);
  assertEquals(parseAmount("COP 25,900"), 25900);
  assertEquals(parseAmount("$ 1.250.000"), 1250000);
});

Deno.test("parseAmount: miles y decimales en ambos formatos", () => {
  assertEquals(parseAmount("$25.900,50"), 25900.5);
  assertEquals(parseAmount("US$1,234.56"), 1234.56);
});

Deno.test("parseAmount: un solo separador con 1 o 2 dígitos es decimal", () => {
  assertEquals(parseAmount("12.50"), 12.5);
  assertEquals(parseAmount("12,5"), 12.5);
});

Deno.test("parseAmount: rechaza vacío, cero, negativos y basura", () => {
  assertEquals(parseAmount(""), null);
  assertEquals(parseAmount("[monto]"), null);
  assertEquals(parseAmount(0), null);
  assertEquals(parseAmount(-5), null);
  assertEquals(parseAmount(null), null);
});

const targets: Target[] = [
  { type: "credit_card", id: "c1", name: "Visa Bancolombia" },
  { type: "credit_card", id: "c2", name: "Nu" },
  { type: "payment_method", id: "p1", name: "Débito Davivienda" },
];

Deno.test("matchTarget: coincidencia exacta ignorando mayúsculas y tildes", () => {
  assertEquals(matchTarget("debito davivienda", targets)?.id, "p1");
  assertEquals(matchTarget("NU", targets)?.id, "c2");
});

Deno.test("matchTarget: el nombre de Wallet contiene el alias o al revés", () => {
  assertEquals(matchTarget("Visa Bancolombia Platinum", targets)?.id, "c1");
  assertEquals(matchTarget("Davivienda", targets)?.id, "p1");
});

Deno.test("matchTarget: exacta gana sobre parcial", () => {
  const both: Target[] = [
    { type: "credit_card", id: "a", name: "Visa" },
    { type: "credit_card", id: "b", name: "Visa Oro" },
  ];
  assertEquals(matchTarget("Visa Oro", both)?.id, "b");
});

Deno.test("matchTarget: sin coincidencia o sin nombre devuelve null", () => {
  assertEquals(matchTarget("Apple Cash", targets), null);
  assertEquals(matchTarget("", targets), null);
  assertEquals(matchTarget(undefined, targets), null);
});

Deno.test("localWallTimestamp: usa la hora local del usuario, no UTC", () => {
  // 01:30 UTC del 2 de octubre son las 20:30 del 1 de octubre en UTC-5.
  const now = new Date("2026-10-02T01:30:00.000Z");
  assertEquals(localWallTimestamp(now, -300), "2026-10-01T20:30:00.000Z");
  assertEquals(localWallTimestamp(now, 0), "2026-10-02T01:30:00.000Z");
});

Deno.test("cardKey: mismo nombre con distinta forma da la misma clave", () => {
  assertEquals(cardKey("Banco de Bogotá"), cardKey("  BANCO DE BOGOTA "));
  assertEquals(cardKey(""), "");
  assertEquals(cardKey(undefined), "");
});

Deno.test("resolveTarget: la asignación guardada gana sobre el parecido de nombre", () => {
  const result = resolveTarget("Nu", targets, { payment_type: "payment_method", payment_ref: "p1" });

  assertEquals(result.target?.id, "p1");
  assertEquals(result.source, "assigned");
});

Deno.test("resolveTarget: sin asignación usa el parecido de nombre", () => {
  const result = resolveTarget("Visa Bancolombia Platinum", targets, null);

  assertEquals(result.target?.id, "c1");
  assertEquals(result.source, "name");
});

Deno.test("resolveTarget: asignación pendiente o a una tarjeta que ya no existe no resuelve", () => {
  const pending = resolveTarget("Visa Signature", targets, { payment_type: null, payment_ref: null });
  assertEquals(pending.target, null);
  assertEquals(pending.source, "none");

  const gone = resolveTarget("Visa Signature", targets, { payment_type: "credit_card", payment_ref: "borrada" });
  assertEquals(gone.target, null);
  assertEquals(gone.source, "none");
});
