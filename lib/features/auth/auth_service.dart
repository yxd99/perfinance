import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  String? get userId => _client.auth.currentUser?.id;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signUpWithEmail(String email, String password) async {
    // Con "Confirm email" desactivado en Supabase (Auth → Providers → Email),
    // el usuario queda confirmado y con sesión de inmediato; no se envía correo.
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
