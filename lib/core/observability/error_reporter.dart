import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/config/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Único punto de contacto con Sentry. Si no hay DSN todas las llamadas son no-op.
class ErrorReporter {
  ErrorReporter._();

  /// Inicializa Sentry y ejecuta [appRunner] dentro de su zona, de modo que los
  /// errores no capturados de Flutter y de la plataforma se reportan solos.
  static Future<void> init(FutureOr<void> Function() appRunner) async {
    if (!SentryConfig.isConfigured) {
      await appRunner();
      return;
    }
    await SentryFlutter.init(
      (options) {
        options.dsn = SentryConfig.dsn;
        options.environment = SentryConfig.environment;
        options.tracesSampleRate = 0;
      },
      appRunner: appRunner,
    );
  }

  /// Asocia los eventos al usuario autenticado; con null los deja anónimos.
  static Future<void> setUser({String? id, String? email}) async {
    await Sentry.configureScope(
      (scope) => scope.setUser(
        id == null ? null : SentryUser(id: id, email: email),
      ),
    );
  }

  /// Reporta un error manejado. [operation] identifica qué se estaba haciendo
  /// (ej. `sync.push`) y [details] agrega el contexto de esa operación.
  static Future<void> capture(
    Object error,
    StackTrace? stackTrace, {
    required String operation,
    Map<String, Object?> details = const {},
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('operation', operation);
        scope.setContexts('details', {
          ...details,
          'local_time': DateTime.now().toIso8601String(),
        });
      },
    );
  }
}

/// Reporta los providers que terminan en error (quedarían solo en la UI).
class ErrorReporterProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    ErrorReporter.capture(
      error,
      stackTrace,
      operation: 'provider',
      details: {'provider': provider.name ?? provider.runtimeType.toString()},
    );
  }
}
