import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _keyOnboardingCompleted(String userId) => 'onboarding_completed_$userId';

final onboardingCompletedProvider =
    AsyncNotifierProvider<OnboardingCompletedNotifier, bool>(OnboardingCompletedNotifier.new);

class OnboardingCompletedNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final userId = ref.watch(authStateProvider).valueOrNull?.id;
    if (userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted(userId)) ?? false;
  }

  Future<void> complete() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted(userId), true);
    state = const AsyncValue.data(true);
  }
}
