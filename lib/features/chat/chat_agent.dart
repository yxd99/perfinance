import 'package:flutter/material.dart';
import 'package:perfinance/core/theme/app_theme.dart';

enum ChatAgent {
  financialAdvisor,
  appAssistant,
  ephemeralChat,
}

/// Rol de color de cada agente; se resuelve por tema con [agentColor].
enum AgentTone { accent, info, warning }

/// Color del agente en el tema actual, con contraste AA sobre la superficie.
Color agentColor(BuildContext context, AgentTone tone) {
  final c = context.colors;
  return switch (tone) {
    AgentTone.accent => c.accent,
    AgentTone.info => c.info,
    AgentTone.warning => c.warning,
  };
}

class ChatAgentConfig {
  final ChatAgent agent;
  final String label;
  final String description;
  final IconData icon;
  final AgentTone tone;
  final bool persistToDb;
  final String systemPrompt;

  const ChatAgentConfig({
    required this.agent,
    required this.label,
    required this.description,
    required this.icon,
    required this.tone,
    required this.persistToDb,
    required this.systemPrompt,
  });
}
