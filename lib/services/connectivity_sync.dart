import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
void startConnectivitySyncListener(void Function() onSync) {
  Connectivity().onConnectivityChanged.listen((list) {
    // En Android, lista vacía puede ser falso negativo; considerar online.
    final offline = list.isNotEmpty && list.every((r) => r == ConnectivityResult.none);
    if (!offline) onSync();
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
