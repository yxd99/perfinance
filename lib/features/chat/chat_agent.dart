import 'package:flutter/material.dart';

enum ChatAgent {
  financialAdvisor,
  appAssistant,
  ephemeralChat,
}

class ChatAgentConfig {
  final ChatAgent agent;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool persistToDb;
  final String systemPrompt;

  const ChatAgentConfig({
    required this.agent,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.persistToDb,
    required this.systemPrompt,
  });
}
