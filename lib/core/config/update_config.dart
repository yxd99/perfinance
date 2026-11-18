/// Configuración del aviso de actualización (`--dart-define`).
///
/// El CI define ambos valores al compilar el APK. En builds locales quedan
/// vacíos y el aviso se desactiva.
class UpdateConfig {
  UpdateConfig._();

  /// Número de build de este APK (el mismo que `--build-number`).
  static const int currentBuild = int.fromEnvironment('APP_BUILD');

  /// ID del archivo `version.json` en Google Drive, compartido por link.
  static const String manifestFileId = String.fromEnvironment('UPDATE_MANIFEST_ID');

  static bool get isConfigured => currentBuild > 0 && manifestFileId.isNotEmpty;

  static Uri get manifestUri => Uri.https(
        'drive.google.com',
        '/uc',
        {'export': 'download', 'id': manifestFileId},
      );
}
