import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perfinance/core/config/update_config.dart';
import 'package:perfinance/core/update/app_update.dart';
import 'package:perfinance/core/update/app_update_provider.dart';

void main() {
  const manifest = {
    'version': '1.2.0',
    'build': 15,
    'url': 'https://github.com/yxd99/perfinance/releases/download/v1.2.0-15/perfinance.apk',
  };

  group('updateCheckEnabled', () {
    test('solo se activa en el build de GitHub Releases con build y repositorio', () {
      expect(
        updateCheckEnabled(currentBuild: 12, repository: 'yxd99/perfinance', distribution: 'github'),
        isTrue,
      );
    });

    test('nunca se activa en el build de Play Store ni en el canal viejo de Drive', () {
      for (final distribution in ['play', '', 'drive']) {
        expect(
          updateCheckEnabled(currentBuild: 12, repository: 'yxd99/perfinance', distribution: distribution),
          isFalse,
          reason: distribution,
        );
      }
    });

    test('sigue apagado en builds locales sin build o sin repositorio', () {
      expect(updateCheckEnabled(currentBuild: 0, repository: 'yxd99/perfinance', distribution: 'github'), isFalse);
      expect(updateCheckEnabled(currentBuild: 12, repository: '', distribution: 'github'), isFalse);
    });

    test('rechaza un repositorio que no tiene la forma dueño/nombre', () {
      for (final repository in ['perfinance', 'yxd99/perfinance/extra', '../evil', 'yxd99/ perfinance']) {
        expect(
          updateCheckEnabled(currentBuild: 12, repository: repository, distribution: 'github'),
          isFalse,
          reason: repository,
        );
      }
    });
  });

  group('releaseManifestUri', () {
    test('apunta al version.json del último release publicado en GitHub', () {
      expect(
        releaseManifestUri('yxd99/perfinance').toString(),
        'https://github.com/yxd99/perfinance/releases/latest/download/version.json',
      );
    });
  });

  group('pendingUpdate', () {
    test('devuelve la versión publicada cuando su build es mayor', () {
      final release = pendingUpdate(manifest, currentBuild: 14);

      expect(release, isNotNull);
      expect(release!.version, '1.2.0');
      expect(release.build, 15);
      expect(release.url, 'https://github.com/yxd99/perfinance/releases/download/v1.2.0-15/perfinance.apk');
    });

    test('no avisa si la app ya tiene ese build o uno mayor', () {
      expect(pendingUpdate(manifest, currentBuild: 15), isNull);
      expect(pendingUpdate(manifest, currentBuild: 20), isNull);
    });

    test('no avisa en builds locales sin número de build (0)', () {
      expect(pendingUpdate(manifest, currentBuild: 0), isNull);
    });

    test('falla con FormatException si el manifiesto está incompleto', () {
      expect(
        () => pendingUpdate({'version': '1.2.0'}, currentBuild: 1),
        throwsFormatException,
      );
    });
  });

  group('fetchPendingUpdate', () {
    final uri = releaseManifestUri('yxd99/perfinance');

    test('lee el manifiesto publicado y devuelve la versión nueva', () async {
      final client = MockClient((_) async => http.Response(jsonEncode(manifest), 200));

      final release = await fetchPendingUpdate(client, manifestUri: uri, currentBuild: 14);

      expect(release?.build, 15);
    });

    test('sin conexión devuelve null en vez de fallar', () async {
      final client = MockClient((_) async => throw http.ClientException('offline'));

      final release = await fetchPendingUpdate(client, manifestUri: uri, currentBuild: 14);

      expect(release, isNull);
    });

    test('una respuesta que no es 200 devuelve null', () async {
      final client = MockClient((_) async => http.Response('not found', 404));

      final release = await fetchPendingUpdate(client, manifestUri: uri, currentBuild: 14);

      expect(release, isNull);
    });
  });
}
