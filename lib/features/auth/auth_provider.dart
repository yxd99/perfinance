import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provee el usuario actual (null si no hay sesión).
final authStateProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((e) => e.session?.user);
});

/// Listenable que notifica cuando cambia el estado de auth (para que go_router re-evalúe redirect).
class AuthRefreshNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;
  AuthRefreshNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authRefreshNotifierProvider = Provider<AuthRefreshNotifier>((ref) {
  final notifier = AuthRefreshNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});
