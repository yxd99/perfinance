/// Canal de distribución que usa el aviso de actualización: el APK publicado
/// en GitHub Releases.
const githubDistribution = 'github';

final _repositoryPattern = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');

/// True solo en el APK que se publica en GitHub Releases. Google Play prohíbe
/// que una app instalada desde la tienda se actualice por fuera de ella, así
/// que cualquier otro canal (Play Store, builds locales) deja el aviso apagado.
bool updateCheckEnabled({
  required int currentBuild,
  required String repository,
  required String distribution,
}) =>
    distribution == githubDistribution &&
    currentBuild > 0 &&
    _repositoryPattern.hasMatch(repository) &&
    !repository.split('/').any((part) => part == '.' || part == '..');

/// Manifiesto `version.json` del último release publicado de [repository]
/// (`dueño/nombre`). GitHub redirige al archivo sin pasar por la API, así que
/// no cuenta contra su límite de pedidos.
Uri releaseManifestUri(String repository) =>
    Uri.https('github.com', '/$repository/releases/latest/download/version.json');

/// Configuración del aviso de actualización (`--dart-define`).
///
/// El job de release del CI define los tres valores al compilar el APK. En el
/// build de Play Store y en builds locales el aviso queda desactivado.
class UpdateConfig {
  UpdateConfig._();

  /// Canal de distribución del build (`DISTRIBUTION`): `github` en el APK de
  /// GitHub Releases; vacío o `play` en cualquier otro caso.
  static const String distribution = String.fromEnvironment('DISTRIBUTION');

  /// Número de build de este APK (el mismo que `--build-number`).
  static const int currentBuild = int.fromEnvironment('APP_BUILD');

  /// Repositorio que publica los releases (`dueño/nombre`). El CI usa el suyo,
  /// así un fork recibe avisos de sus propios releases.
  static const String repository = String.fromEnvironment('UPDATE_REPOSITORY');

  static bool get isConfigured => updateCheckEnabled(
        currentBuild: currentBuild,
        repository: repository,
        distribution: distribution,
      );

  static Uri get manifestUri => releaseManifestUri(repository);
}
