import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/features/chat/chat_agent.dart';
import 'package:perfinance/features/chat/chat_agent_configs.dart';
import 'package:perfinance/features/chat/chat_copy.dart';
import 'package:perfinance/features/chat/chat_provider.dart';
import 'package:perfinance/features/chat/chat_types.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadConversations();
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatProvider, (_, state) {
      if (state.status != ChatStatus.loading) _scrollToBottom();
    });
    final state = ref.watch(chatProvider);
    final c = context.colors;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.canvas,
      appBar: AppBar(
        // Con el Drawer, el AppBar pondría una hamburguesa en lugar de «atrás».
        // El historial se abre desde el ícono de lista del compositor.
        automaticallyImplyLeading: false,
        leading: (ModalRoute.of(context)?.canPop ?? false) ? const BackButton() : null,
        title: const Text('Asesor financiero'),
        actions: [
          if (state.activeConversation != null)
            IconButton(
              icon: const Icon(CupertinoIcons.trash),
              onPressed: () => _confirmDeleteConversation(state),
              tooltip: 'Eliminar conversación',
            ),
          if (!state.isEphemeral)
            IconButton(
              icon: const Icon(CupertinoIcons.square_pencil),
              onPressed: () => ref.read(chatProvider.notifier).newConversation(),
              tooltip: 'Nueva conversación',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _AgentPicker(
            selected: state.activeAgent,
            onChanged: (agent) => ref.read(chatProvider.notifier).switchAgent(agent),
          ),
        ),
      ),
      drawer: state.isEphemeral ? null : _buildConversationDrawer(state),
      body: Column(
        children: [
          Expanded(child: _buildChatList(state)),
          if (state.status == ChatStatus.error)
            _ChatErrorBar(
              message: chatErrorMessage(state.error),
              onRetry: () => ref.read(chatProvider.notifier).retryLastMessage(),
            ),
          if (state.pendingAction != null) _buildActionPrompt(state.pendingAction!),
          _buildInputBar(state),
        ],
      ),
    );
  }

  Widget _buildConversationDrawer(ChatState state) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Drawer(
      backgroundColor: c.canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Semantics(header: true, child: Text('Conversaciones', style: t.titleLarge?.copyWith(color: c.ink))),
            ),
            Expanded(
              child: state.conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Todavía no hay conversaciones.\nEscribí para empezar una.',
                          textAlign: TextAlign.center,
                          style: t.bodyMedium?.copyWith(color: c.textMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: state.conversations.length,
                      separatorBuilder: (_, _) => Divider(height: 1, thickness: 0.5, indent: 16, color: c.divider),
                      itemBuilder: (context, index) {
                        final convo = state.conversations[index];
                        final isActive = state.activeConversation?.id == convo.id;
                        return ListTile(
                          selected: isActive,
                          selectedTileColor: c.accentSoft,
                          selectedColor: c.ink,
                          title: Text(
                            convo.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyLarge?.copyWith(fontWeight: isActive ? FontWeight.w600 : null),
                          ),
                          subtitle: Text(
                            DateFormat('dd MMM, HH:mm').format(convo.updatedAt),
                            style: t.bodySmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures),
                          ),
                          trailing: IconButton(
                            icon: Icon(CupertinoIcons.xmark, size: 16, color: c.textMuted),
                            tooltip: 'Eliminar conversación',
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

  Widget _buildChatList(ChatState state) {
    if (state.messages.isEmpty && state.currentResponse.isEmpty && state.status != ChatStatus.loading) {
      return _buildEmptyState(state);
    }

    final showThinking = state.status == ChatStatus.loading && state.currentResponse.isEmpty;
    final itemCount = state.messages.length + (showThinking ? 1 : 0) + (state.currentResponse.isNotEmpty ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == state.messages.length && showThinking) {
          return _ThinkingBubble(tone: state.agentConfig.tone);
        }
        if (index == state.messages.length + (showThinking ? 1 : 0) && state.currentResponse.isNotEmpty) {
          return _MessageBubble(
            message: ChatMessage(role: ChatMessageRole.assistant, content: state.currentResponse),
            tone: state.agentConfig.tone,
            isStreaming: true,
          );
        }
        return _MessageBubble(message: state.messages[index], tone: state.agentConfig.tone);
      },
    );
  }

  Widget _buildEmptyState(ChatState state) {
    final config = state.agentConfig;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final count = state.conversations.length;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(config.icon, size: 40, color: agentColor(context, config.tone))),
            const SizedBox(height: 12),
            Text(config.description, textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: c.ink)),
            const SizedBox(height: 16),
            Text(
              _hintForAgent(state.activeAgent),
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: c.textMuted),
            ),
            if (!state.isEphemeral && count > 0) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(CupertinoIcons.list_bullet, size: 18),
                label: Text(count == 1 ? 'Ver 1 conversación' : 'Ver $count conversaciones'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _hintForAgent(ChatAgent agent) {
    switch (agent) {
      case ChatAgent.financialAdvisor:
        return 'Preguntame sobre tus gastos y deudas, o pedime un análisis.\n\n'
            '"¿Cómo van mis finanzas este mes?"\n'
            '"¿Cuánto gasté en enero?"\n'
            '"Compará enero con febrero"';
      case ChatAgent.appAssistant:
        return 'Contame qué pagaste y lo registro por vos.\n\n'
            '"Gasté 50 mil en el súper"\n'
            '"Registrá un pago de 200 mil a la deuda del celular"\n'
            '"Pagué la tarjeta Visa"';
      case ChatAgent.ephemeralChat:
        return 'Preguntas rápidas, sin tus datos. Los mensajes no se guardan.\n\n'
            '"¿Qué es el interés compuesto?"\n'
            '"Dame ideas para ahorrar"';
    }
  }

  Widget _buildActionPrompt(ActionRequired action) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(action.prompt, style: t.bodyMedium?.copyWith(color: c.ink)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in action.options)
                  ActionChip(
                    label: Text(opt.label),
                    labelStyle: t.labelLarge?.copyWith(color: c.ink),
                    onPressed: () => ref.read(chatProvider.notifier).resolveAction(opt.value),
                    backgroundColor: c.accentSoft,
                    side: BorderSide(color: c.divider, width: 0.5),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ChatState state) {
    final isBusy = state.status == ChatStatus.loading || state.status == ChatStatus.streaming;
    final canSend = !isBusy && _textController.text.trim().isNotEmpty;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: c.canvas,
        border: Border(top: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!state.isEphemeral)
                IconButton(
                  icon: Icon(CupertinoIcons.list_bullet, color: c.accent),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  tooltip: 'Conversaciones',
                )
              else
                const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: !isBusy,
                  style: t.bodyLarge?.copyWith(color: c.ink),
                  decoration: InputDecoration(
                    hintText: _hintForInput(state.activeAgent),
                    hintStyle: t.bodyLarge?.copyWith(color: c.textMuted),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: c.divider),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: c.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: c.accent, width: 1.5),
                    ),
                  ),
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: isBusy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                      : Semantics(
                          button: true,
                          enabled: canSend,
                          label: 'Enviar',
                          child: GestureDetector(
                            onTap: canSend ? _sendMessage : null,
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: canSend ? c.accent : c.track,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.arrow_up,
                                    size: 18,
                                    color: canSend ? c.onAccent : c.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hintForInput(ChatAgent agent) {
    switch (agent) {
      case ChatAgent.financialAdvisor:
        return 'Preguntá sobre tus finanzas';
      case ChatAgent.appAssistant:
        return 'Registrá algo o consultá datos';
      case ChatAgent.ephemeralChat:
        return 'Escribí tu pregunta';
    }
  }

  Future<void> _confirmDeleteConversation(ChatState state) async {
    final convo = state.activeConversation;
    if (convo == null) return;
    final platform = Theme.of(context).platform;
    final isCupertino = platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('¿Eliminar esta conversación?'),
        content: const Text('Se borran todos sus mensajes. No se puede deshacer.'),
        actions: isCupertino
            ? [
                CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Eliminar'),
                ),
              ]
            : [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: context.colors.danger),
                  child: const Text('Eliminar'),
                ),
              ],
      ),
    );
    if (ok == true) await ref.read(chatProvider.notifier).deleteConversation(convo);
  }
}

/// Selector de agente: control segmentado nativo bajo la barra.
class _AgentPicker extends StatelessWidget {
  const _AgentPicker({required this.selected, required this.onChanged});

  final ChatAgent selected;
  final ValueChanged<ChatAgent> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<ChatAgent>(
          groupValue: selected,
          backgroundColor: c.track,
          thumbColor: c.surface,
          children: {
            for (final agent in ChatAgent.values)
              agent: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  ChatAgentConfigs.forAgent(agent).label,
                  style: TextStyle(color: c.ink, fontWeight: agent == selected ? FontWeight.w600 : FontWeight.w500),
                ),
              ),
          },
          onValueChanged: (agent) {
            if (agent != null) onChanged(agent);
          },
        ),
      ),
    );
  }
}

class _ChatErrorBar extends StatelessWidget {
  const _ChatErrorBar({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        decoration: BoxDecoration(color: c.dangerSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_circle, size: 18, color: c.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.danger)),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: c.danger),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.tone});

  final AgentTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        liveRegion: true,
        label: 'Pensando',
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: c.surface, borderRadius: _bubbleRadius(isUser: false)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: agentColor(context, tone)),
              ),
              const SizedBox(width: 8),
              Text('Pensando…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

BorderRadius _bubbleRadius({required bool isUser}) => BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 18),
    );

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.tone, this.isStreaming = false});

  final ChatMessage message;
  final AgentTone tone;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatMessageRole.user;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final toneColor = agentColor(context, tone);
    final body = t.bodyLarge?.copyWith(color: isUser ? c.onAccent : c.ink, height: 1.4);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.78 : 0.88)),
        child: GestureDetector(
          onLongPress: isUser
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mensaje copiado'), duration: Duration(seconds: 1)),
                  );
                },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser ? c.accent : c.surface,
              borderRadius: _bubbleRadius(isUser: isUser),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUser)
                  Text(message.content, style: body)
                else
                  MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: body,
                      listBullet: body,
                      strong: body?.copyWith(fontWeight: FontWeight.w700),
                      h1: t.titleLarge?.copyWith(color: c.ink),
                      h2: t.titleMedium?.copyWith(color: c.ink),
                      h3: t.titleSmall?.copyWith(color: c.ink),
                      tableBody: t.bodyMedium?.copyWith(color: c.ink, fontFeatures: kTabularFigures),
                      tableHead: t.bodyMedium?.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                      code: t.bodyMedium?.copyWith(backgroundColor: c.track, color: toneColor),
                      codeblockDecoration: BoxDecoration(color: c.track, borderRadius: BorderRadius.circular(8)),
                      blockquote: body?.copyWith(color: c.textMuted),
                      blockquoteDecoration: BoxDecoration(
                        color: c.track,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (isStreaming)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: toneColor),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
