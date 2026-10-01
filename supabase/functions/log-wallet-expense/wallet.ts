export type Target = {
  type: "credit_card" | "payment_method";
  id: string;
  name: string;
};

/**
 * El atajo de iOS manda el monto como número o como texto con formato de
 * moneda ("$25.900", "COP 25,900.50"). Devuelve null si no es un monto válido.
 */
export function parseAmount(raw: unknown): number | null {
  if (typeof raw === "number") {
    return Number.isFinite(raw) && raw > 0 ? raw : null;
  }
  if (typeof raw !== "string") return null;

  let digits = raw.replace(/[^\d.,]/g, "");
  if (!/\d/.test(digits)) return null;

  const lastDot = digits.lastIndexOf(".");
  const lastComma = digits.lastIndexOf(",");
  let decimalSep: string | null = null;
  if (lastDot >= 0 && lastComma >= 0) {
    // Con ambos separadores, el último es el decimal.
    decimalSep = lastDot > lastComma ? "." : ",";
  } else if (lastDot >= 0 || lastComma >= 0) {
    const sep = lastDot >= 0 ? "." : ",";
    const parts = digits.split(sep);
    // Repetido, o seguido de exactamente 3 dígitos, es separador de miles.
    const isThousands = parts.length > 2 || parts[parts.length - 1].length === 3;
    if (!isThousands) decimalSep = sep;
  }

  if (decimalSep) {
    const i = digits.lastIndexOf(decimalSep);
    digits = `${digits.slice(0, i).replace(/[.,]/g, "")}.${digits.slice(i + 1)}`;
  } else {
    digits = digits.replace(/[.,]/g, "");
  }

  const value = Number(digits);
  return Number.isFinite(value) && value > 0 ? value : null;
}

/** Clave estable de un nombre de tarjeta: sin tildes, mayúsculas ni símbolos. */
export function cardKey(name: string | undefined | null): string {
  return (name ?? "")
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
}

/**
 * Busca la tarjeta o medio de pago de la app que corresponde al nombre de la
 * tarjeta en Wallet: primero igualdad, después que un nombre contenga al otro.
 */
export function matchTarget(cardName: string | undefined | null, targets: Target[]): Target | null {
  const wanted = cardKey(cardName);
  if (!wanted) return null;

  const exact = targets.find((t) => cardKey(t.name) === wanted);
  if (exact) return exact;

  return targets.find((t) => {
    const name = cardKey(t.name);
    return name.length > 0 && (wanted.includes(name) || name.includes(wanted));
  }) ?? null;
}

/** Fila de `wallet_cards`: a qué medio de pago asignó el usuario una tarjeta de Wallet. */
export type Assignment = { payment_type: string | null; payment_ref: string | null } | null;

/**
 * Decide a qué medio de pago va el egreso: primero la asignación que el
 * usuario guardó en la app (si ese medio sigue existiendo), después el
 * parecido de nombre.
 */
export function resolveTarget(
  cardName: string | undefined | null,
  targets: Target[],
  assignment: Assignment,
): { target: Target | null; source: "assigned" | "name" | "none" } {
  if (assignment?.payment_type && assignment.payment_ref) {
    const assigned = targets.find(
      (t) => t.type === assignment.payment_type && t.id === assignment.payment_ref,
    );
    if (assigned) return { target: assigned, source: "assigned" };
  }
  const byName = matchTarget(cardName, targets);
  return byName ? { target: byName, source: "name" } : { target: null, source: "none" };
}

/**
 * La app guarda las fechas como hora local sin zona. Devuelve la hora local
 * del usuario escrita como si fuera UTC, igual que hace la app al subir.
 */
export function localWallTimestamp(now: Date, utcOffsetMinutes: number): string {
  return new Date(now.getTime() + utcOffsetMinutes * 60_000).toISOString();
}
