import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/features/chat/chat_agent.dart';
import 'package:perfinance/features/chat/chat_agent_configs.dart';
import 'package:perfinance/features/chat/chat_types.dart';
import 'package:perfinance/data/models/chat_conversation.dart';
import 'package:perfinance/data/repositories/chat_conversation_repository.dart';
import 'package:perfinance/services/financial_advisor_service.dart';

enum ChatStatus { idle, loading, streaming, error }

class ChatState {
  final List<ChatMessage> messages;
  final String currentResponse;
  final ChatStatus status;
  final String? error;
  final ActionRequired? pendingAction;
  final ChatAgent activeAgent;
  final ChatConversation? activeConversation;
  final List<ChatConversation> conversations;

  const ChatState({
    this.messages = const [],
    this.currentResponse = '',
    this.status = ChatStatus.idle,
    this.error,
    this.pendingAction,
    this.activeAgent = ChatAgent.financialAdvisor,
    this.activeConversation,
    this.conversations = const [],
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? currentResponse,
    ChatStatus? status,
    String? error,
    ActionRequired? pendingAction,
    ChatAgent? activeAgent,
    ChatConversation? activeConversation,
    List<ChatConversation>? conversations,
    bool clearCurrentResponse = false,
    bool clearError = false,
    bool clearPendingAction = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        currentResponse: clearCurrentResponse ? '' : (currentResponse ?? this.currentResponse),
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
        pendingAction: clearPendingAction ? null : (pendingAction ?? this.pendingAction),
        activeAgent: activeAgent ?? this.activeAgent,
        activeConversation: activeConversation ?? this.activeConversation,
        conversations: conversations ?? this.conversations,
      );

  ChatAgentConfig get agentConfig => ChatAgentConfigs.forAgent(activeAgent);
  bool get isEphemeral => activeAgent == ChatAgent.ephemeralChat;
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatAIService _service;
  final ChatConversationRepository _repo;
  StreamSubscription<SSEEvent>? _subscription;
  bool _streamDone = true;

  ChatNotifier(this._service, this._repo) : super(const ChatState());

  Future<void> switchAgent(ChatAgent agent) async {
    if (agent == state.activeAgent) return;
    _subscription?.cancel();
    state = state.copyWith(
      activeAgent: agent,
      messages: const [],
      currentResponse: '',
      status: ChatStatus.idle,
      clearError: true,
      clearPendingAction: true,
      activeConversation: null,
    );
    await _loadConversations(agent);
  }

  Future<void> loadConversations() async {
    await _loadConversations(state.activeAgent);
  }

  Future<void> _loadConversations(ChatAgent agent) async {
    if (agent == ChatAgent.ephemeralChat) {
      state = state.copyWith(conversations: const []);
      return;
    }
    try {
      final convos = await _repo.getConversations(agent.name);
      state = state.copyWith(conversations: convos);
    } catch (e) {
      // ignore: avoid_print
      print('[ChatProvider] _loadConversations error: $e');
    }
  }

  Future<void> openConversation(ChatConversation conversation) async {
    _subscription?.cancel();
    final messages = await _repo.getMessages(conversation.id);
    state = state.copyWith(
      activeConversation: conversation,
      messages: messages,
      currentResponse: '',
      status: ChatStatus.idle,
      clearError: true,
      clearPendingAction: true,
    );
  }

  Future<void> newConversation() async {
    _subscription?.cancel();
    state = state.copyWith(
      activeConversation: null,
      messages: const [],
      currentResponse: '',
      status: ChatStatus.idle,
      clearError: true,
      clearPendingAction: true,
    );
  }

  Future<void> deleteConversation(ChatConversation conversation) async {
    await _repo.deleteConversation(conversation.id);
    if (state.activeConversation?.id == conversation.id) {
      await newConversation();
    }
    await _loadConversations(state.activeAgent);
  }

  Future<void> sendMessage(String text) async {
    print('[Chat] sendMessage: "$text"');
    if (text.trim().isEmpty || state.status == ChatStatus.loading || state.status == ChatStatus.streaming) return;

    final userMessage = ChatMessage(role: ChatMessageRole.user, content: text, createdAt: DateTime.now());

    final updatedMessages = [...state.messages, userMessage];
    state = state.copyWith(
      messages: updatedMessages,
      status: ChatStatus.loading,
      clearCurrentResponse: true,
      clearError: true,
      clearPendingAction: true,
    );

    // Auto-create conversation on first message (persistent agents)
    if (state.activeConversation == null && !state.isEphemeral) {
      try {
        final title = text.length > 40 ? '${text.substring(0, 40)}...' : text;
        final convo = await _repo.createConversation(state.activeAgent.name, title);
        state = state.copyWith(activeConversation: convo);
        await _loadConversations(state.activeAgent);
      } catch (e) {
        // DB failed — continue ephemeral for this session
      }
    }

    // Save user message to DB if persistent
    if (state.activeConversation != null && !state.isEphemeral) {
      try {
        await _repo.saveMessage(state.activeConversation!.id, userMessage);
      } catch (e) {
        // Message saved in memory, DB sync failed
      }
    }

    // Build history for context (last 20 messages max)
    final history = state.messages
        .where((m) => m.role != ChatMessageRole.system)
        .take(20)
        .map((m) => ChatMessage(role: m.role, content: m.content))
        .toList();

    StringBuffer responseBuffer = StringBuffer();

    _subscription?.cancel();
    _streamDone = false;
    _subscription = _service
        .chat(
          message: text,
          history: history,
          agent: state.activeAgent,
          onChunk: (chunk) => responseBuffer.write(chunk),
        )
        .listen(
      (event) {
        print('[Chat] event: ${event.type}, data: ${event.data}');
        switch (event.type) {
          case 'content':
            final done = event.data['done'] as bool? ?? false;
            final fullContent = responseBuffer.toString();
            if (done) {
              if (fullContent.isNotEmpty) {
                final assistantMsg = ChatMessage(
                  role: ChatMessageRole.assistant,
                  content: fullContent,
                  createdAt: DateTime.now(),
                );
                final newMessages = [...state.messages, assistantMsg];
                state = state.copyWith(
                  messages: newMessages,
                  status: _streamDone ? ChatStatus.idle : ChatStatus.loading,
                  clearCurrentResponse: true,
                );
                if (state.activeConversation != null && !state.isEphemeral) {
                  _repo.saveMessage(state.activeConversation!.id, assistantMsg);
                }
              } else {
                state = state.copyWith(
                  status: _streamDone ? ChatStatus.idle : ChatStatus.loading,
                  clearCurrentResponse: true,
                );
              }
              responseBuffer = StringBuffer();
            } else {
              state = state.copyWith(
                status: ChatStatus.streaming,
                currentResponse: fullContent,
              );
            }
            break;
          case 'action_required':
            final action = ActionRequired.fromJson(event.data);
            state = state.copyWith(
              pendingAction: action,
              status: ChatStatus.idle,
            );
            break;
          case 'error':
            state = state.copyWith(
              status: ChatStatus.error,
              error: event.data['text'] as String? ?? 'Error desconocido',
            );
            break;
        }
      },
      onError: (e) {
        print('[Chat] onError: $e');
        _streamDone = true;
        state = state.copyWith(
          status: ChatStatus.error,
          error: e.toString(),
        );
      },
      onDone: () {
        print('[Chat] onDone, status=${state.status}, buffer="${responseBuffer.toString().length}"');
        _streamDone = true;
        if (state.status == ChatStatus.streaming || state.status == ChatStatus.loading) {
          final finalContent = responseBuffer.toString();
          if (finalContent.isNotEmpty) {
            final assistantMsg = ChatMessage(
              role: ChatMessageRole.assistant,
              content: finalContent,
              createdAt: DateTime.now(),
            );
            state = state.copyWith(
              messages: [...state.messages, assistantMsg],
              status: ChatStatus.idle,
              clearCurrentResponse: true,
            );
            if (state.activeConversation != null && !state.isEphemeral) {
              _repo.saveMessage(state.activeConversation!.id, assistantMsg);
            }
          } else {
            state = state.copyWith(status: ChatStatus.idle, clearCurrentResponse: true);
          }
        }
      },
    );
  }

  void resolveAction(String value) {
    if (state.pendingAction == null) return;
    sendMessage(value);
  }

  void clearChat() {
    _subscription?.cancel();
    state = state.copyWith(
      messages: const [],
      currentResponse: '',
      status: ChatStatus.idle,
      clearError: true,
      clearPendingAction: true,
      activeConversation: null,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    ref.read(chatAIServiceProvider),
    ChatConversationRepository(),
  );
});
