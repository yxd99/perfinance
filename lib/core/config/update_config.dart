/// Canal de distribución que usa el aviso de actualización por Drive.
const driveDistribution = 'drive';

/// True solo en el APK que se distribuye por Google Drive. Google Play prohíbe
/// que una app instalada desde la tienda se actualice por fuera de ella, así
/// que cualquier otro canal (Play Store, builds locales) deja el aviso apagado.
bool updateCheckEnabled({
  required int currentBuild,
  required String manifestFileId,
  required String distribution,
}) =>
    distribution == driveDistribution && currentBuild > 0 && manifestFileId.isNotEmpty;

/// Configuración del aviso de actualización (`--dart-define`).
///
/// El job de Drive del CI define los tres valores al compilar el APK. En el
/// build de Play Store y en builds locales el aviso queda desactivado.
class UpdateConfig {
  UpdateConfig._();

  /// Canal de distribución del build (`DISTRIBUTION`): `drive` en el APK de
  /// Drive; vacío o `play` en cualquier otro caso.
  static const String distribution = String.fromEnvironment('DISTRIBUTION');

  /// Número de build de este APK (el mismo que `--build-number`).
  static const int currentBuild = int.fromEnvironment('APP_BUILD');

  /// ID del archivo `version.json` en Google Drive, compartido por link.
  static const String manifestFileId = String.fromEnvironment('UPDATE_MANIFEST_ID');

  static bool get isConfigured => updateCheckEnabled(
        currentBuild: currentBuild,
        manifestFileId: manifestFileId,
        distribution: distribution,
      );

  static Uri get manifestUri => Uri.https(
        'drive.google.com',
        '/uc',
        {'export': 'download', 'id': manifestFileId},
      );
}
