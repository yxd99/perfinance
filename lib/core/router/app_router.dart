import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perfinance/core/router/deep_link_debug_screen.dart';
import 'package:perfinance/core/router/deep_link_listener.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/auth/login_screen.dart';
import 'package:perfinance/features/auth/register_screen.dart';
import 'package:perfinance/features/chat/chat_screen.dart';
import 'package:perfinance/features/expenses/expense_form_screen.dart';
import 'package:perfinance/features/onboarding/home_or_onboarding_wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(authRefreshNotifierProvider);
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeOrOnboardingWrapper()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
      GoRoute(path: '/debug', builder: (_, __) => const DeepLinkDebugScreen()),
      GoRoute(
        path: '/log-expense',
        builder: (_, state) {
          final query = state.uri.queryParameters;
          return ExpenseFormScreen(
            initialAmount: double.tryParse(query['amount'] ?? ''),
            initialDescription: query['merchant'],
          );
        },
      ),
    ],
  );
  final deepLinkListener = DeepLinkListener(router);
  ref.onDispose(deepLinkListener.dispose);
  return router;
});
