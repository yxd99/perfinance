import { assertEquals } from "jsr:@std/assert@1";
import { isValidEmail, normalizeEmail } from "./recipient.ts";

Deno.test("normalizeEmail: minúsculas y sin espacios", () => {
  assertEquals(normalizeEmail("  Juan.Perez@Gmail.COM "), "juan.perez@gmail.com");
});

Deno.test("isValidEmail: acepta correos comunes", () => {
  assertEquals(isValidEmail("juan@gmail.com"), true);
  assertEquals(isValidEmail("maria.lopez+cobros@empresa.com.co"), true);
});

Deno.test("isValidEmail: rechaza formatos que no son correo", () => {
  for (const email of [
    "",
    "not-an-email",
    "juan@gmail",
    "juan@.com",
    "juan@gmail.",
    "@gmail.com",
    "juan perez@gmail.com",
    "juan@@gmail.com",
    "juan@gmail..com",
    "a@b.co,otro@x.com",
  ]) {
    assertEquals(isValidEmail(email), false, email);
  }
});
