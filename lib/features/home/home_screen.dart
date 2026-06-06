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

  int get _selectedIndex => _tabController.index;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _titles.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startConnectivitySyncListener(
        () => ref.read(syncServiceProvider).syncNow(),
      );
      _syncIfOnline();
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

  Future<void> _syncIfOnline() async {
    final list = await Connectivity().checkConnectivity();
    // En Android, lista vacía puede ser falso negativo; intentar sync si está vacía.
    final offline =
        list.isNotEmpty && list.every((r) => r == ConnectivityResult.none);
    if (!offline) {
      await ref.read(syncServiceProvider).syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip:
                'Sincronizar ahora (se sincroniza automáticamente con conexión)',
            onPressed: () async {
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sincronizando...')));
              try {
                await ref.read(syncServiceProvider).syncNow();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sincronización completada')),
                  );
                }
              } catch (_) {
                if (mounted) {
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(syncServiceProvider).clearLocalDataOnLogout();
              ref.invalidate(databaseProvider);
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
