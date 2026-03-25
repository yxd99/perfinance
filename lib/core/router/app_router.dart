import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/auth/login_screen.dart';
import 'package:perfinance/features/auth/register_screen.dart';
import 'package:perfinance/features/onboarding/home_or_onboarding_wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(authRefreshNotifierProvider);
  return GoRouter(
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
    ],
  );
});
