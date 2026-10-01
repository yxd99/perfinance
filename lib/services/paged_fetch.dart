/// Supabase corta cada respuesta en 1000 filas sin avisar.
const int defaultPageSize = 1000;

/// Pide páginas a [fetchPage] (rango inclusivo `from`..`to`) hasta agotarlas.
/// Una página incompleta marca el final.
Future<List<Map<String, dynamic>>> fetchAllPages(
  Future<List<dynamic>> Function(int from, int to) fetchPage, {
  int pageSize = defaultPageSize,
}) async {
  final all = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    final page = await fetchPage(from, from + pageSize - 1);
    for (final row in page) {
      all.add(Map<String, dynamic>.from(row as Map));
    }
    if (page.length < pageSize) return all;
    from += pageSize;
  }
}
