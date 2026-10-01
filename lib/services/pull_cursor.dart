/// Margen hacia atrás al pedir cambios: cubre escrituras que se confirman en la
/// nube con una marca de tiempo anterior a la última fila ya vista.
const Duration pullOverlap = Duration(minutes: 5);

/// Desde cuándo pedir cambios dado el [cursor] guardado. `null` = descarga completa.
String? pullSince(String? cursor) {
  if (cursor == null) return null;
  return DateTime.parse(cursor).toUtc().subtract(pullOverlap).toIso8601String();
}

/// Nuevo cursor tras procesar [rows]: la marca de tiempo del servidor más
/// reciente vista. Usa la hora de la nube, nunca el reloj del dispositivo.
String? advanceCursor(
  String? cursor,
  Iterable<Map<String, dynamic>> rows, {
  String column = 'updated_at',
}) {
  var latest = cursor == null ? null : DateTime.parse(cursor).toUtc();
  for (final row in rows) {
    final raw = row[column];
    if (raw == null) continue;
    final at = DateTime.parse(raw.toString()).toUtc();
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest?.toIso8601String();
}
