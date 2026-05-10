const List<String> _monthAbbreviations = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Formatea una fecha como '15 may 2026'. La conversión de zona horaria
/// es responsabilidad del caller — este helper no llama `.toLocal()`.
String formatDisplayDate(DateTime date) =>
    '${date.day} ${_monthAbbreviations[date.month - 1]} ${date.year}';
