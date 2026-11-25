import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/config/supabase_config.dart';
import 'package:perfinance/core/utils/email.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ReceivableNotificationEvent {
  created,
  paymentRecorded,
  paymentEdited,
  paymentDeleted,
  reminder,
}

/// Qué pasó con el aviso por email.
enum NotificationResult {
  /// El servidor envió el correo.
  sent,

  /// El destinatario aún no está aprobado en `email_recipient_allowlist`; el
  /// servidor registró el intento y no envió nada.
  pendingApproval,

  /// La cuenta llegó a su tope mensual de correos (`email_quotas`); no se envió.
  quotaExceeded,

  /// No se llamó al servidor (sin email válido o sin Supabase configurado).
  skipped,
}

/// Frase para el usuario sobre lo que pasó con el aviso a [email]. Null cuando
/// no hay nada que contar ([NotificationResult.skipped]).
String? notificationNotice(NotificationResult result, String email) => switch (result) {
      NotificationResult.sent => 'Le avisamos a $email.',
      NotificationResult.pendingApproval => 'El aviso a $email quedó pendiente de aprobación.',
      NotificationResult.quotaExceeded =>
        'Llegaste al límite de correos de este mes; no le enviamos el aviso a $email.',
      NotificationResult.skipped => null,
    };

class ReceivableNotificationPayload {
  const ReceivableNotificationPayload({
    required this.event,
    required this.recipientEmail,
    required this.debtorName,
    required this.totalAmount,
    required this.remainingBalance,
    this.creditorEmail,
    this.isRegistered = false,
    this.paymentAmount,
    this.paymentDate,
    this.receivableId,
    this.description,
  });

  final ReceivableNotificationEvent event;
  final String recipientEmail;
  final String debtorName;
  final double totalAmount;
  final double remainingBalance;

  /// The creditor's email — always included in the payload (spec S5).
  final String? creditorEmail;

  /// Whether the debtor is a registered app user.
  /// When true the email template mentions the debt is visible in the app.
  final bool isRegistered;

  final double? paymentAmount;
  final DateTime? paymentDate;
  final String? receivableId;

  /// Descripción del cobro; el correo la muestra para dar contexto.
  final String? description;
}

final receivableNotificationServiceProvider =
    Provider<ReceivableNotificationService>((ref) {
  return ReceivableNotificationService(Supabase.instance.client);
});

class ReceivableNotificationService {
  ReceivableNotificationService(this._client, {bool? isConfiguredOverride})
      : _isConfigured = isConfiguredOverride ?? SupabaseConfig.isConfigured;

  final SupabaseClient _client;
  final bool _isConfigured;

  Future<NotificationResult> notify(ReceivableNotificationPayload payload) async {
    if (!isValidEmail(payload.recipientEmail)) return NotificationResult.skipped;
    if (!_isConfigured) return NotificationResult.skipped;

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
      if (token == null || token.isEmpty) throw Exception('NO_USER_SESSION');
      return token;
    }

    Future<FunctionResponse> invokeNotify(String accessToken) {
      final body = <String, dynamic>{
        'event': _eventWire(payload.event),
        'recipientEmail': payload.recipientEmail.trim(),
        'debtorName': payload.debtorName,
        'totalAmount': payload.totalAmount,
        'remainingBalance': payload.remainingBalance,
        // creditorEmail is always included (spec S5: any notification payload contains it)
        'creditorEmail': payload.creditorEmail ?? '',
        // isRegistered drives the email template branch (spec S5)
        'isRegistered': payload.isRegistered,
        if (payload.paymentAmount != null) 'paymentAmount': payload.paymentAmount,
        if (payload.paymentDate != null)
          'paymentDate': payload.paymentDate!.toIso8601String(),
        if (payload.receivableId != null) 'receivableId': payload.receivableId,
        if (payload.description?.trim().isNotEmpty ?? false)
          'description': payload.description!.trim(),
      };
      return _client.functions.invoke(
        'send-receivable-notification',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: body,
      );
    }

    Future<FunctionResponse> invokeWithTimeout(String token) {
      return invokeNotify(token).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException(
          'Tiempo de espera agotado al enviar la notificación.',
        ),
      );
    }

    try {
      var token = await ensureAccessToken();
      FunctionResponse res;
      try {
        res = await invokeWithTimeout(token);
      } on FunctionException catch (e) {
        if (e.status != 401) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 650));
        token = _client.auth.currentSession?.accessToken ?? token;
        res = await invokeWithTimeout(token);
      }

      final data = res.data;
      if (data is Map && data['ok'] != true) {
        throw Exception(_parseError(data, res.status));
      }
      if (data is Map && data['status'] == 'pending_approval') {
        return NotificationResult.pendingApproval;
      }
      if (data is Map && data['status'] == 'quota_exceeded') {
        return NotificationResult.quotaExceeded;
      }
      return NotificationResult.sent;
    } on FunctionException catch (e) {
      throw Exception(_parseError(e.details, e.status));
    }
  }

  String _eventWire(ReceivableNotificationEvent event) => switch (event) {
        ReceivableNotificationEvent.created => 'created',
        ReceivableNotificationEvent.paymentRecorded => 'payment_recorded',
        ReceivableNotificationEvent.paymentEdited => 'payment_edited',
        ReceivableNotificationEvent.paymentDeleted => 'payment_deleted',
        ReceivableNotificationEvent.reminder => 'reminder',
      };

  String _parseError(dynamic data, int status) {
    if (data is Map) {
      final main = data['error']?.toString() ?? data['message']?.toString();
      if (main != null) return '$main ($status)';
    }
    if (data is String && data.isNotEmpty) return '$data (HTTP $status)';
    return 'HTTP $status';
  }
}
