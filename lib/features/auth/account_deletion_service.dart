import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService(Supabase.instance.client);
});

/// Elimina la cuenta en Supabase con la edge function `delete-account`. La
/// función usa la sesión actual; la base local la borra quien llama.
class AccountDeletionService {
  AccountDeletionService(this._client);

  final SupabaseClient _client;

  /// Termina sin error solo si el servidor confirmó el borrado.
  Future<void> deleteAccount() async {
    try {
      final res = await _client.functions
          .invoke('delete-account')
          .timeout(const Duration(seconds: 30));
      final data = res.data;
      if (data is! Map || data['ok'] != true) {
        throw Exception('delete-account no confirmó el borrado (HTTP ${res.status}): $data');
      }
    } on FunctionException catch (e) {
      throw Exception('delete-account falló (HTTP ${e.status}): ${e.details}');
    }
  }
}
