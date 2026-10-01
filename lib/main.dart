import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/config/supabase_config.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/router/app_router.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'Faltan SUPABASE_URL y/o SUPABASE_ANON_KEY. '
      'Ejemplo: flutter run --dart-define-from-file=dart_defines.json '
      'o --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... '
      '(plantilla en dart_defines.json.example).',
    );
  }
  await ErrorReporter.init(() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    final auth = Supabase.instance.client.auth;
    await ErrorReporter.setUser(
      id: auth.currentUser?.id,
      email: auth.currentUser?.email,
    );
    auth.onAuthStateChange.listen((state) {
      final user = state.session?.user;
      ErrorReporter.setUser(id: user?.id, email: user?.email);
    });
    runApp(
      ProviderScope(
        observers: [ErrorReporterProviderObserver()],
        child: const PerfinanceApp(),
      ),
    );
  });
}

class PerfinanceApp extends ConsumerWidget {
  const PerfinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Perfinance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
