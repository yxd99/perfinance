import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/data/models/chat_conversation.dart';
import 'package:perfinance/features/chat/chat_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatConversationRepository {
  final _client = Supabase.instance.client;

  Future<List<ChatConversation>> getConversations(String agentType) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from('chat_conversations')
          .select()
          .eq('user_id', userId)
          .eq('agent_type', agentType)
          .order('updated_at', ascending: false);

      return (rows as List).map((j) => ChatConversation.fromJson(Map<String, dynamic>.from(j as Map))).toList();
    } catch (e, st) {
      ErrorReporter.capture(
        e,
        st,
        operation: 'chat.get_conversations',
        details: {'agent_type': agentType},
      );
      return [];
    }
  }

  Future<ChatConversation> createConversation(String agentType, String title) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('No user logged in');

    final now = DateTime.now().toIso8601String();
    await _client.from('chat_conversations').insert({
      'user_id': userId,
      'agent_type': agentType,
      'title': title,
      'created_at': now,
      'updated_at': now,
    });

    // Query back the just-created conversation
    final rows = await _client
        .from('chat_conversations')
        .select()
        .eq('user_id', userId)
        .eq('agent_type', agentType)
        .order('created_at', ascending: false);

    final list = rows as List;
    if (list.isEmpty) throw Exception('Conversation created but not found');
    return ChatConversation.fromJson(Map<String, dynamic>.from(list.first as Map));
  }

  Future<void> updateTitle(String conversationId, String title) async {
    await _client
        .from('chat_conversations')
        .update({'title': title, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);
  }

  Future<void> deleteConversation(String conversationId) async {
    await _client.from('chat_conversations').delete().eq('id', conversationId);
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    try {
      final rows = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (rows as List).map((j) {
        final map = Map<String, dynamic>.from(j as Map);
        final role = ChatMessageRole.values.firstWhere(
          (r) => r.name == map['role'],
          orElse: () => ChatMessageRole.assistant,
        );
        return ChatMessage(
          id: map['id'] as String?,
          role: role,
          content: map['content'] as String,
          createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveMessage(String conversationId, ChatMessage message) async {
    await _client.from('chat_messages').insert({
      'conversation_id': conversationId,
      'role': message.role.name,
      'content': message.content,
      'created_at': (message.createdAt ?? DateTime.now()).toIso8601String(),
    });

    await _client
        .from('chat_conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);
  }
}
