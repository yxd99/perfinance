import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyHideValues = 'hide_values';

final hideValuesProvider = AsyncNotifierProvider<HideValuesNotifier, bool>(HideValuesNotifier.new);

class HideValuesNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHideValues) ?? false;
  }

  Future<void> toggle() async {
    state.whenOrNull(
      data: (hide) async {
        final prefs = await SharedPreferences.getInstance();
        final next = !hide;
        await prefs.setBool(_keyHideValues, next);
        state = AsyncValue.data(next);
      },
    );
  }
}
