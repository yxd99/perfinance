/// Versión publicada de la app según el manifiesto `version.json` que el CI
/// sube a Google Drive junto al APK.
class AppRelease {
  const AppRelease({required this.version, required this.build, required this.url});

  /// Nombre visible, p. ej. `1.2.0`.
  final String version;

  /// Número de build (versionCode de Android). Es lo que se compara.
  final int build;

  /// Link de descarga del APK.
  final String url;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final build = json['build'];
    final url = json['url'];
    if (version is! String || build is! int || url is! String || url.isEmpty) {
      throw FormatException('Manifiesto de versión inválido', json.toString());
    }
    return AppRelease(version: version, build: build, url: url);
  }
}

/// Devuelve la versión publicada si es más nueva que [currentBuild].
///
/// Un [currentBuild] de 0 es un build local (sin `APP_BUILD`): nunca avisa.
AppRelease? pendingUpdate(Map<String, dynamic> manifest, {required int currentBuild}) {
  final release = AppRelease.fromJson(manifest);
  if (currentBuild <= 0 || release.build <= currentBuild) return null;
  return release;
}
