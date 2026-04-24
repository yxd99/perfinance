import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/config/supabase_config.dart';
import 'package:perfinance/features/expenses/expense_export_window.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final expenseExportServiceProvider = Provider<ExpenseExportService>((ref) {
  return ExpenseExportService(Supabase.instance.client);
});

class ExpenseExportService {
  ExpenseExportService(this._client);

  final SupabaseClient _client;

  /// Llama la Edge Function `send-expense-export`; lanza si falla HTTP o respuesta no OK.
  Future<void> sendExpenseExportEmail(ExpenseExportWindow window) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('SUPABASE_URL / SUPABASE_ANON_KEY no configurados.');
    }

    try {
      Future<String> ensureAccessToken() async {
        var session = _client.auth.currentSession;
        if (session == null) throw Exception('NO_USER_SESSION');

        if (!session.isExpired) return session.accessToken;

        try {
          final authResp = await _client.auth.refreshSession().timeout(
                const Duration(seconds: 12),
              );
          session = authResp.session ?? _client.auth.currentSession;
        } catch (e) {
          throw Exception('SESSION_REFRESH_FAILED: $e');
        }

        final token = session?.accessToken;
        if (token == null || token.isEmpty) {
          throw Exception('NO_USER_SESSION');
        }
        return token;
      }

      Future<FunctionResponse> invokeSendExport(
        String accessToken,
        String? recipientEmail,
      ) {
        final body = <String, dynamic>{
          'rangeLabel': window.rangeLabel,
          'windowStartIso': window.windowStartIso,
          'windowEndIso': window.windowEndIso,
          'timezoneOffsetMinutes': window.timezoneOffsetMinutes,
        };
        final e = recipientEmail?.trim();
        if (e != null && e.isNotEmpty) {
          body['recipientEmail'] = e;
        }
        // Solo Bearer: `apikey` lo añade AuthHttpClient (misma clave que Supabase.initialize).
        return _client.functions.invoke(
          'send-expense-export',
          headers: {'Authorization': 'Bearer $accessToken'},
          body: body,
        );
      }

      /// Los logs de Supabase mostraban dos POST a `/token` seguidos y dos 401: el reintento
      /// llamaba otra vez a `refreshSession()`, revocando el access token anterior (token_revoked).
      Future<FunctionResponse> invokeWithTimeout(
        String token,
        String? email,
      ) {
        return invokeSendExport(token, email).timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw TimeoutException(
            'Tiempo de espera agotado al llamar a la función de correo.',
          ),
        );
      }

      var token = await ensureAccessToken();
      var recipientEmail = _client.auth.currentSession?.user.email?.trim();
      FunctionResponse res;
      try {
        res = await invokeWithTimeout(token, recipientEmail);
      } on FunctionException catch (e) {
        if (e.status != 401) rethrow;
        // Sin segundo refresh: esperar a que otro refresh en segundo plano termine y reintentar.
        await Future<void>.delayed(const Duration(milliseconds: 650));
        token = _client.auth.currentSession?.accessToken ?? token;
        recipientEmail =
            _client.auth.currentSession?.user.email?.trim() ?? recipientEmail;
        res = await invokeWithTimeout(token, recipientEmail);
      }

      final data = res.data;
      if (data is Map && data['ok'] != true) {
        final err = _parseFunctionError(data, res.status);
        throw Exception(err);
      }
    } on FunctionException catch (e) {
      final err = _parseFunctionError(e.details, e.status);
      throw Exception(err);
    }
  }

  /// Combina `error`, `hint` y `detail` (p. ej. respuesta JSON de Resend) en un solo mensaje.
  String _parseFunctionError(dynamic data, int status) {
    if (data is Map) {
      final hint = data['hint']?.toString();
      final main = data['error']?.toString() ??
          data['message']?.toString() ??
          data['msg']?.toString();
      final detail = data['detail'];

      String? detailMessage;
      if (detail is Map) {
        final d = detail['message'];
        if (d != null) detailMessage = d.toString();
        final errors = detail['errors'];
        if (detailMessage == null && errors is List && errors.isNotEmpty) {
          final first = errors.first;
          if (first is Map && first['message'] != null) {
            detailMessage = first['message'].toString();
          }
        }
      }

      if (hint != null && hint.isNotEmpty) {
        return '${main ?? 'Error'} ($status): $hint';
      }
      if (detailMessage != null && detailMessage.isNotEmpty) {
        return '${main ?? 'Error'} ($status): $detailMessage';
      }
      if (detail is Map) {
        return '${main ?? 'Error'} ($status): ${detail.toString()}';
      }
      if (main != null) return '$main ($status)';
    }
    if (data is String && data.isNotEmpty) return '$data (HTTP $status)';
    return 'HTTP $status';
  }
}
