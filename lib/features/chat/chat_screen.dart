import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/theme/app_tokens.dart';
import 'package:perfinance/features/chat/chat_agent.dart';
import 'package:perfinance/features/chat/chat_agent_configs.dart';
import 'package:perfinance/features/chat/chat_provider.dart';
import 'package:perfinance/features/chat/chat_types.dart';
import 'package:intl/intl.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _agentTabController;

  @override
  void initState() {
    super.initState();
    _agentTabController = TabController(length: ChatAgent.values.length, vsync: this);
    _agentTabController.addListener(_onAgentTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadConversations();
    });
  }

  void _onAgentTabChanged() {
    if (_agentTabController.indexIsChanging) return;
    final agent = ChatAgent.values[_agentTabController.index];
    ref.read(chatProvider.notifier).switchAgent(agent);
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _resolveAction(String value) {
    ref.read(chatProvider.notifier).resolveAction(value);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _agentTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatProvider, (_, state) {
      if (state.status == ChatStatus.streaming || state.status == ChatStatus.idle) {
        _scrollToBottom();
      }
    });
    final state = ref.watch(chatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final agentConfig = state.agentConfig;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(agentConfig.label),
        actions: [
          if (state.activeConversation != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showDeleteConversationDialog(state),
              tooltip: 'Eliminar conversación',
            ),
          if (!state.isEphemeral)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: () => ref.read(chatProvider.notifier).newConversation(),
              tooltip: 'Nueva conversación',
            ),
        ],
        bottom: TabBar(
          controller: _agentTabController,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          tabs: ChatAgent.values.map((agent) {
            final config = ChatAgentConfigs.forAgent(agent);
            return Tab(
              icon: Icon(config.icon, size: 20),
              text: config.label,
            );
          }).toList(),
        ),
      ),
      drawer: state.isEphemeral ? null : _buildConversationDrawer(state),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildChatList(state, isDark)),
                if (state.pendingAction != null) _buildActionPrompt(state.pendingAction!),
              ],
            ),
          ),
          _buildInputBar(state, agentConfig),
        ],
      ),
    );
  }

  Widget _buildConversationDrawer(ChatState state) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceLG),
              child: Text(
                'Conversaciones',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: state.conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.spaceXL),
                        child: Text(
                          'Sin conversaciones aún.\nEscribí para empezar una.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.conversations.length,
                      itemBuilder: (context, index) {
                        final convo = state.conversations[index];
                        final isActive = state.activeConversation?.id == convo.id;
                        return ListTile(
                          selected: isActive,
                          selectedTileColor: AppThemeColors.primaryGreen.withValues(alpha: 0.1),
                          leading: Icon(
                            state.agentConfig.icon,
                            size: 20,
                            color: isActive ? AppThemeColors.primaryGreen : Colors.grey,
                          ),
                          title: Text(
                            convo.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('dd MMM, HH:mm').format(convo.updatedAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                            onPressed: () => ref.read(chatProvider.notifier).deleteConversation(convo),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            ref.read(chatProvider.notifier).openConversation(convo);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(ChatState state, bool isDark) {
    if (state.messages.isEmpty && state.status == ChatStatus.idle) {
      return _buildEmptyState(state, isDark);
    }

    final showThinking = state.status == ChatStatus.loading && state.currentResponse.isEmpty;
    final itemCount = state.messages.length +
        (showThinking ? 1 : 0) +
        (state.currentResponse.isNotEmpty ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTokens.spaceMD),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == state.messages.length && showThinking) {
          return _buildThinkingBubble(isDark);
        }
        if (index == state.messages.length + (showThinking ? 1 : 0) && state.currentResponse.isNotEmpty) {
          return _buildMessageBubble(
            ChatMessage(role: ChatMessageRole.assistant, content: state.currentResponse),
            isDark,
            isStreaming: true,
          );
        }
        return _buildMessageBubble(state.messages[index], isDark);
      },
    );
  }

  Widget _buildEmptyState(ChatState state, bool isDark) {
    final config = state.agentConfig;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(config.icon, size: 64, color: config.color.withValues(alpha: 0.5)),
            const SizedBox(height: AppTokens.spaceLG),
            Text(
              config.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTokens.spaceSM),
            Text(
              config.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: AppTokens.spaceXL),
            if (state.isEphemeral)
              Text(
                'Los mensajes no se guardan.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
              )
            else ...[
              if (state.conversations.isNotEmpty) ...[
                Text(
                  '${state.conversations.length} conversación${state.conversations.length > 1 ? 'es' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const SizedBox(height: AppTokens.spaceSM),
              ],
              Text(
                _getHintForAgent(state.activeAgent),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getHintForAgent(ChatAgent agent) {
    switch (agent) {
      case ChatAgent.financialAdvisor:
        return 'Preguntame sobre tus gastos, deudas, o pedime un análisis.\n\n'
            'Ej: "¿Cómo van mis finanzas este mes?"\n'
            '"¿Cuánto gasté en enero?"\n'
            '"Compará mis gastos de enero vs febrero"';
      case ChatAgent.appAssistant:
        return 'Ayudarte a registrar datos en la app.\n\n'
            'Ej: "Hice una compra de 50 mil en el super"\n'
            '"Registrá un pago de 200 mil a la deuda del celular"\n'
            '"Pagué la tarjeta Visa"';
      case ChatAgent.ephemeralChat:
        return 'Chat rápido sin persistencia.\n\n'
            'Ej: "¿Qué es el interés compuesto?"\n'
            '"Dame tips para ahorrar"';
    }
  }

  Widget _buildThinkingBubble(bool isDark) {
    final agentConfig = ref.read(chatProvider).agentConfig;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: agentConfig.color.withValues(alpha: 0.2),
            child: Icon(agentConfig.icon, size: 16, color: agentConfig.color),
          ),
          const SizedBox(width: AppTokens.spaceSM),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceLG, vertical: AppTokens.spaceMD),
            decoration: BoxDecoration(
              color: isDark ? AppThemeColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTokens.radiusLG),
                topRight: Radius.circular(AppTokens.radiusLG),
                bottomRight: Radius.circular(AppTokens.radiusLG),
              ),
              boxShadow: isDark
                  ? null
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: agentConfig.color,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSM),
                Text(
                  'Pensando...',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark, {bool isStreaming = false}) {
    final isUser = message.role == ChatMessageRole.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXS),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: ref.read(chatProvider).agentConfig.color.withValues(alpha: 0.2),
              child: Icon(ref.read(chatProvider).agentConfig.icon, size: 16, color: ref.read(chatProvider).agentConfig.color),
            ),
            const SizedBox(width: AppTokens.spaceSM),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: isUser
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mensaje copiado'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceLG, vertical: AppTokens.spaceMD),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDark ? AppThemeColors.primaryGreenDark : AppThemeColors.primaryGreen)
                    : (isDark ? AppThemeColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTokens.radiusLG),
                  topRight: const Radius.circular(AppTokens.radiusLG),
                  bottomLeft: isUser ? const Radius.circular(AppTokens.radiusLG) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(AppTokens.radiusLG),
                ),
                boxShadow: isDark
                    ? null
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        strong: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        code: TextStyle(
                          backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
                          fontSize: 13,
                          color: ref.read(chatProvider).agentConfig.color,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(left: BorderSide(color: ref.read(chatProvider).agentConfig.color, width: 3)),
                        ),
                      ),
                    ),
                  if (isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isUser ? Colors.white70 : ref.read(chatProvider).agentConfig.color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ),
          ),
          if (isUser) const SizedBox(width: AppTokens.spaceSM),
        ],
      ),
    );
  }

  Widget _buildActionPrompt(ActionRequired action) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceLG),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(action.prompt, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppTokens.spaceMD),
            Wrap(
              spacing: AppTokens.spaceSM,
              runSpacing: AppTokens.spaceSM,
              children: action.options.map((opt) {
                return ActionChip(
                  label: Text(opt.label, style: const TextStyle(fontSize: 13)),
                  onPressed: () => _resolveAction(opt.value),
                  backgroundColor: AppThemeColors.primaryGreen.withValues(alpha: 0.1),
                side: BorderSide(color: AppThemeColors.primaryGreen.withValues(alpha: 0.3)),
              );
            }).toList(),
          ),
        ],
       ),
      ),
    );
  }

  Widget _buildInputBar(ChatState state, ChatAgentConfig agentConfig) {
    final isLoading = state.status == ChatStatus.loading || state.status == ChatStatus.streaming;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppTokens.spaceMD, AppTokens.spaceSM, AppTokens.spaceSM, AppTokens.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (!state.isEphemeral)
            Padding(
              padding: const EdgeInsets.only(right: AppTokens.spaceSM),
              child: IconButton(
                icon: const Icon(Icons.menu_rounded, size: 22),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                tooltip: 'Conversaciones',
              ),
            ),
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !isLoading,
              decoration: InputDecoration(
                hintText: _getHintForInput(state.activeAgent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLG),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceLG, vertical: AppTokens.spaceSM),
                isDense: true,
              ),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: AppTokens.spaceSM),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [agentConfig.color, agentConfig.color.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_upward, color: Colors.white),
              onPressed: isLoading ? null : _sendMessage,
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getHintForInput(ChatAgent agent) {
    switch (agent) {
      case ChatAgent.financialAdvisor:
        return 'Preguntá sobre tus finanzas...';
      case ChatAgent.appAssistant:
        return 'Registrá algo o consultá datos...';
      case ChatAgent.ephemeralChat:
        return 'Escribí rápido...';
    }
  }

  void _showDeleteConversationDialog(ChatState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar conversación'),
        content: const Text('¿Seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (state.activeConversation != null) {
                ref.read(chatProvider.notifier).deleteConversation(state.activeConversation!);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppThemeColors.errorRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
