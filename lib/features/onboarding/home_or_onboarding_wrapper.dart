import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/onboarding_provider.dart';
import 'package:perfinance/features/home/home_screen.dart';
import 'package:perfinance/features/onboarding/onboarding_screen.dart';

/// Muestra onboarding la primera vez que el usuario entra a la app (tras login).
/// Si ya completó el onboarding, muestra [HomeScreen].
class HomeOrOnboardingWrapper extends ConsumerWidget {
  const HomeOrOnboardingWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(onboardingCompletedProvider).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (_, __) => const HomeScreen(),
          data: (completed) => completed ? const HomeScreen() : const OnboardingScreen(),
        );
  }
}
