import 'package:flutter/foundation.dart';

class DeepLinkEvent {
  DeepLinkEvent({required this.receivedAt, required this.uri});

  final DateTime receivedAt;
  final Uri uri;
}

/// In-memory history of every deep link the app has received this session,
/// for debugging the iOS Shortcuts (Apple Pay) automation.
class DeepLinkDebugLog extends ValueNotifier<List<DeepLinkEvent>> {
  DeepLinkDebugLog._() : super([]);

  static final DeepLinkDebugLog instance = DeepLinkDebugLog._();

  static const _maxEntries = 30;

  void add(Uri uri) {
    value = [
      DeepLinkEvent(receivedAt: DateTime.now(), uri: uri),
      ...value,
    ].take(_maxEntries).toList();
  }
}
