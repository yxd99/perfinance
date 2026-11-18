import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:perfinance/core/config/update_config.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/update/app_update.dart';

/// Consulta el manifiesto publicado y devuelve la versión nueva, si la hay.
///
/// Sin red devuelve `null` sin reportar: estar offline es normal. Un manifiesto
/// roto o una respuesta inesperada sí se reportan.
Future<AppRelease?> fetchPendingUpdate(
  http.Client client, {
  required Uri manifestUri,
  required int currentBuild,
}) async {
  try {
    final response = await client.get(manifestUri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException('version.json respondió ${response.statusCode}', uri: manifestUri);
    }
    final manifest = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return pendingUpdate(manifest, currentBuild: currentBuild);
  } on SocketException {
    return null; // Sin conexión: se vuelve a consultar al próximo arranque.
  } on TimeoutException {
    return null;
  } on http.ClientException {
    return null;
  } catch (e, st) {
    await ErrorReporter.capture(
      e,
      st,
      operation: 'update.check',
      details: {'currentBuild': currentBuild},
    );
    return null;
  }
}

/// Versión nueva disponible para descargar. Solo Android: en iOS la app no se
/// instala desde Drive.
final pendingUpdateProvider = FutureProvider<AppRelease?>((ref) async {
  if (!Platform.isAndroid || !UpdateConfig.isConfigured) return null;
  final client = http.Client();
  try {
    return await fetchPendingUpdate(
      client,
      manifestUri: UpdateConfig.manifestUri,
      currentBuild: UpdateConfig.currentBuild,
    );
  } finally {
    client.close();
  }
});
