const List<String> _monthAbbreviations = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Formatea una fecha como '15 may 2026'. La conversión de zona horaria
/// es responsabilidad del caller — este helper no llama `.toLocal()`.
String formatDisplayDate(DateTime date) =>
    '${date.day} ${_monthAbbreviations[date.month - 1]} ${date.year}';

/// Parsea un string ISO proveniente de Supabase descartando la parte de tiempo.
/// Supabase devuelve timestamps como '2026-04-15T00:00:00+00' — solo usamos
/// los primeros 10 caracteres para obtener la fecha local sin drift de offset.
DateTime parseDateOnly(String isoStr) => DateTime.parse(isoStr.substring(0, 10));

/// Igual que [parseDateOnly] pero tolera strings nulos o cortos.
/// Devuelve [DateTime.now()] como fallback cuando el string no es parseable.
DateTime tryParseDateOnly(String? isoStr) {
  if (isoStr == null || isoStr.length < 10) return DateTime.now();
  return DateTime.tryParse(isoStr.substring(0, 10)) ?? DateTime.now();
}

/// Serializa una fecha como 'YYYY-MM-DD' para enviar a Supabase.
/// Evita que el timestamp completo de toIso8601String() genere drift al guardarse.
String dateOnlyIso(DateTime dt) => dt.toIso8601String().substring(0, 10);
