import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Llama [onSync] únicamente cuando la app recupera conexión (offline→online).
/// Evita disparar sync en cada cambio de red (ej: WiFi→datos, datos→WiFi).
void startConnectivitySyncListener(void Function() onSync) {
  bool? wasOffline;
  Connectivity().onConnectivityChanged.listen((list) {
    final offline = list.isNotEmpty && list.every((r) => r == ConnectivityResult.none);
    if (wasOffline == true && !offline) onSync();
    wasOffline = offline;
  });
}

final connectivityStatusProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = FutureProvider<bool>((ref) async {
  final list = await Connectivity().checkConnectivity();
  // Lista vacía en Android no significa offline; asumir online.
  if (list.isEmpty) return true;
  return !list.every((r) => r == ConnectivityResult.none);
});
