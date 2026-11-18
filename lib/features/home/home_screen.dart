import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_colors.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_screen.dart';
import 'package:perfinance/features/debts/debts_screen.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/expenses_screen.dart';
import 'package:perfinance/features/expenses/quick_add_expense.dart';
import 'package:perfinance/features/home/home_tab_bar.dart';
import 'package:perfinance/features/more/more_screen.dart';
import 'package:perfinance/services/connectivity_sync.dart';
import 'package:perfinance/services/process_automatic_payments_service.dart';
import 'package:perfinance/services/sync_service.dart';

/// Shell principal: barra inferior Mes · Egresos · + · Deudas · Más.
///
/// Al abrir sincroniza si los datos están viejos, procesa los pagos automáticos
/// y escucha la red para subir lo pendiente al reconectar.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  int _index = 0;

  /// Pestañas ya abiertas: se construyen la primera vez que se visitan y
  /// después se conservan (scroll, filtros) al cambiar de sección.
  final Set<int> _visited = {0};

  static const _bodies = <Widget>[
    DashboardScreen(),
    ExpensesScreen(),
    DebtsScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Al recuperar la red: sube lo pendiente y baja lo cambiado, sin banner.
      _connectivitySub = startConnectivitySyncListener(
        () => ref.read(syncServiceProvider).syncNow(silent: true).catchError(
              (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'home.sync'),
            ),
      );
      _syncIfStale();
      _processAutomaticPayments();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _processAutomaticPayments() async {
    await ref.read(processAutomaticPaymentsServiceProvider).run();
    ref.invalidate(expensesListProvider);
    ref.invalidate(automaticPaymentsListProvider);
  }

  Future<void> _syncIfStale() async {
    final list = await Connectivity().checkConnectivity();
    final offline = list.isNotEmpty && list.every((r) => r == ConnectivityResult.none);
    if (offline) return;
    final syncService = ref.read(syncServiceProvider);
    final lastSync = await syncService.getLastSync();
    final isStale = lastSync == null ||
        DateTime.now().difference(lastSync) > const Duration(minutes: 5);
    if (isStale) await syncService.syncNow();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingChangesCountProvider).valueOrNull ?? 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _SyncingStrip(),
            const _OfflineBanner(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < _bodies.length; i++)
                    _visited.contains(i) ? _bodies[i] : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: HomeTabBar(
        currentIndex: _index,
        pendingCount: pending,
        onSelect: _select,
        onAdd: () => showQuickAddExpense(context, ref),
      ),
    );
  }
}

/// Franja fina mientras corre una sincronización visible (no las silenciosas).
class _SyncingStrip extends ConsumerWidget {
  const _SyncingStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isSyncingProvider)) return const SizedBox.shrink();
    final c = context.colors;
    return Material(
      color: c.track,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
            ),
            const SizedBox(width: 8),
            Text(
              'Sincronizando datos...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(connectivityStatusProvider).when(
          data: (list) {
            // En Android, connectivity_plus a veces devuelve lista vacía teniendo internet.
            // Solo mostrar "sin conexión" cuando haya resultado explícito y sea none.
            final offline = list.isNotEmpty && list.every((r) => r == ConnectivityResult.none);
            if (!offline) return const SizedBox.shrink();
            return Material(
              color: context.colors.warningSoft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Center(
                  child: Text(
                    'Sin conexión. Los datos se sincronizarán al recuperar la red.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.warning),
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }
}
