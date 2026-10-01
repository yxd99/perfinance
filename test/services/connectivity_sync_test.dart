import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/services/connectivity_sync.dart';

void main() {
  late StreamController<List<ConnectivityResult>> changes;
  late int syncs;

  setUp(() {
    changes = StreamController<List<ConnectivityResult>>();
    syncs = 0;
  });

  tearDown(() => changes.close());

  Future<void> emit(List<ConnectivityResult> state) async {
    changes.add(state);
    await Future<void>.delayed(Duration.zero);
  }

  test('sincroniza al pasar de sin conexión a conectado', () async {
    final sub = startConnectivitySyncListener(() => syncs++, changes: changes.stream);

    await emit([ConnectivityResult.none]);
    await emit([ConnectivityResult.wifi]);

    expect(syncs, 1);
    await sub.cancel();
  });

  test('no sincroniza al cambiar de red sin haber estado offline', () async {
    final sub = startConnectivitySyncListener(() => syncs++, changes: changes.stream);

    await emit([ConnectivityResult.wifi]);
    await emit([ConnectivityResult.mobile]);

    expect(syncs, 0);
    await sub.cancel();
  });

  test('cancelar la suscripción deja de sincronizar', () async {
    final sub = startConnectivitySyncListener(() => syncs++, changes: changes.stream);

    await emit([ConnectivityResult.none]);
    await sub.cancel();
    await emit([ConnectivityResult.wifi]);

    expect(syncs, 0);
  });
}
