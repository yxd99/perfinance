import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:perfinance/core/router/deep_link_debug_log.dart';

/// Listens for `perfinance://<path>?<query>` links (e.g. from an iOS
/// Shortcuts automation) and forwards them to [GoRouter] as an in-app route.
class DeepLinkListener {
  DeepLinkListener(this._router) {
    _appLinks = AppLinks();
    _sub = _appLinks.uriLinkStream.listen(_handleUri);
    // uriLinkStream can miss the link that cold-started the app on iOS.
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });
  }

  final GoRouter _router;
  late final AppLinks _appLinks;
  late final StreamSubscription<Uri> _sub;

  void _handleUri(Uri uri) {
    // El link puede traer tokens de login: no guardarlo ni escribirlo en logcat
    // fuera de debug.
    if (kDebugMode) {
      DeepLinkDebugLog.instance.add(uri);
      debugPrint('[DeepLink] received: $uri');
    }
    if (uri.scheme != 'perfinance') return;
    final path = uri.host.isEmpty ? '/' : '/${uri.host}${uri.path}';
    _router.go(Uri(path: path, queryParameters: uri.queryParameters).toString());
  }

  void dispose() => _sub.cancel();
}
