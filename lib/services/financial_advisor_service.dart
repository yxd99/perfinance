import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:perfinance/core/config/supabase_config.dart';
import 'package:perfinance/features/chat/chat_agent.dart';
import 'package:perfinance/features/chat/chat_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatAIService {
  ChatAIService();

  String get _edgeFunctionUrl =>
      '${SupabaseConfig.url}/functions/v1/financial-advisor';

  Future<String?> _authToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken;
  }

  Stream<SSEEvent> chat({
    required String message,
    required List<ChatMessage> history,
    required ChatAgent agent,
    void Function(String chunk)? onChunk,
  }) async* {
    final token = await _authToken();
    if (token == null) {
      yield SSEEvent(type: 'error', data: {'text': 'No hay sesión activa'});
      return;
    }

    final historyMessages = history
        .map((m) => {'role': m.role.name, 'content': m.content})
        .toList();

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(_edgeFunctionUrl))
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          'message': message,
          'history': historyMessages,
          'agent_type': agent.name,
        });

      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        yield SSEEvent(type: 'error', data: {'text': 'Error ${response.statusCode}: $body'});
        return;
      }

      String eventType = 'content';
      StringBuffer dataBuffer = StringBuffer();

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final char in chunk.split('')) {
          if (char == '\n') {
            final line = dataBuffer.toString().trim();
            dataBuffer.clear();

            if (line.isEmpty) {
              eventType = 'content';
              continue;
            }

            if (line.startsWith('event: ')) {
              eventType = line.substring(7).trim();
              continue;
            }

            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6).trim();
              try {
                final data = jsonDecode(jsonStr) as Map<String, dynamic>;
                final event = SSEEvent(type: eventType, data: data);
                yield event;
                if (event.type == 'content' && event.data['text'] is String) {
                  onChunk?.call(event.data['text'] as String);
                }
              } catch (_) {}
              continue;
            }
          } else {
            dataBuffer.write(char);
          }
        }
      }
    } finally {
      client.close();
    }
  }
}

final chatAIServiceProvider = Provider<ChatAIService>((ref) {
  return ChatAIService();
});

@Deprecated('Use chatAIServiceProvider instead')
final financialAdvisorServiceProvider = chatAIServiceProvider;
