import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/features/auth/auth_service.dart';
import 'package:perfinance/features/credit_cards/credit_cards_screen.dart';
import 'package:perfinance/features/dashboard/dashboard_screen.dart';
import 'package:perfinance/features/debts/debts_screen.dart';
import 'package:perfinance/features/receivables/receivables_screen.dart';
import 'package:perfinance/features/expenses/expenses_screen.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_screen.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/savings/savings_screen.dart';
import 'package:perfinance/services/connectivity_sync.dart';
import 'package:perfinance/services/process_automatic_payments_service.dart';
import 'package:perfinance/services/sync_service.dart';
import 'dart:math' show pi;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<String> _titles = [
    'Dashboard',
    'Egresos',
    'Tarjetas',
    'Ahorros',
    'Deudas',
    'Me deben',
    'Auto-pagos',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _titles.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startConnectivitySyncListener(
        () => ref.read(syncServiceProvider).pushPendingIfOnline(),
      );
      _syncIfStale();
      _processAutomaticPayments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  /// Cerrar sesión borra la base local: antes se sube lo pendiente y, si algo
  /// no pudo subirse, se pide confirmación porque esos cambios se perderían.
  Future<void> _logout() async {
    final syncService = ref.read(syncServiceProvider);
    final pending = await syncService.pushAndCountPending();
    if (!mounted) return;
    if (pending > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambios sin sincronizar'),
          content: Text(
            pending == 1
                ? 'Hay 1 cambio que no se pudo subir a la nube. Si cerrás sesión ahora se pierde.'
                : 'Hay $pending cambios que no se pudieron subir a la nube. Si cerrás sesión ahora se pierden.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar sesión igual'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await syncService.clearLocalDataOnLogout();
    ref.invalidate(databaseProvider);
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isSyncing = ref.watch(isSyncingProvider);
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Image.asset(AppAssets.logo, height: 32, fit: BoxFit.contain),
          ),
        ),
        leadingWidth: 120,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.payments), text: 'Egresos'),
            Tab(icon: Icon(Icons.credit_card), text: 'Tarjetas'),
            Tab(icon: Icon(Icons.savings), text: 'Ahorros'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Deudas'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Me deben'),
            Tab(icon: Icon(Icons.autorenew), text: 'Auto-pagos'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Asesor financiero',
            onPressed: () => context.push('/chat'),
          ),
          ref
              .watch(hideValuesProvider)
              .when(
                data: (hideValues) => IconButton(
                  icon: Icon(
                    hideValues ? Icons.visibility : Icons.visibility_off,
                  ),
                  tooltip: hideValues ? 'Mostrar valores' : 'Ocultar valores',
                  onPressed: () =>
                      ref.read(hideValuesProvider.notifier).toggle(),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          _SyncIconButton(isSyncing: isSyncing),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          if (isSyncing)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Sincronizando datos...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ref
              .watch(connectivityStatusProvider)
              .when(
                data: (list) {
                  // En Android, connectivity_plus a veces devuelve lista vacía teniendo internet.
                  // Solo mostrar "sin conexión" cuando haya resultado explícito y sea none.
                  final offline =
                      list.isNotEmpty &&
                      list.every((r) => r == ConnectivityResult.none);
                  if (!offline) return const SizedBox.shrink();
                  return Material(
                    color: Colors.orange.shade700,
                    child: const SafeArea(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            'Sin conexión. Los datos se sincronizarán al recuperar la red.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                DashboardScreen(),
                ExpensesScreen(),
                CreditCardsScreen(),
                SavingsScreen(),
                DebtsScreen(),
                ReceivablesScreen(),
                AutomaticPaymentsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncIconButton extends ConsumerStatefulWidget {
  const _SyncIconButton({required this.isSyncing});
  final bool isSyncing;

  @override
  ConsumerState<_SyncIconButton> createState() => _SyncIconButtonState();
}

class _SyncIconButtonState extends ConsumerState<_SyncIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isSyncing) _controller.repeat();
  }

  @override
  void didUpdateWidget(_SyncIconButton old) {
    super.didUpdateWidget(old);
    if (widget.isSyncing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isSyncing && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingChangesCountProvider).valueOrNull ?? 0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Transform.rotate(
        angle: _controller.value * 2 * pi,
        child: child,
      ),
      child: IconButton(
        icon: Badge(
          isLabelVisible: pending > 0,
          label: Text('$pending'),
          child: const Icon(Icons.sync),
        ),
        tooltip: pending > 0
            ? '$pending cambios sin subir. Tocá para sincronizar'
            : 'Sincronizar ahora (se sincroniza automáticamente con conexión)',
        onPressed: widget.isSyncing
            ? null
            : () async {
                if (!context.mounted) return;
                try {
                  await ref.read(syncServiceProvider).syncNow();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(UserFriendlyErrors.syncFailed),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
      ),
    );
  }
}
