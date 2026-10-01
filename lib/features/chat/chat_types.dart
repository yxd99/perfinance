import 'dart:convert';

enum ChatMessageRole { user, assistant, system }

class ChatMessage {
  final String? id;
  final ChatMessageRole role;
  final String content;
  final DateTime? createdAt;

  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.createdAt,
  });

  ChatMessage copyWith({String? content}) =>
      ChatMessage(id: id, role: role, content: content ?? this.content, createdAt: createdAt);
}

class SSEEvent {
  final String type;
  final Map<String, dynamic> data;

  SSEEvent({required this.type, required this.data});

  factory SSEEvent.fromLine(String line) {
    final eventMatch = RegExp(r'^event: (.+)$').firstMatch(line);
    final dataMatch = RegExp(r'^data: (.+)$').firstMatch(line);
    final type = eventMatch?.group(1) ?? 'content';
    final dataStr = dataMatch?.group(1) ?? '{}';
    Map<String, dynamic> data = {};
    try {
      data = Map<String, dynamic>.from(
        (jsonDecode(dataStr) as Map).map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {}
    return SSEEvent(type: type, data: data);
  }
}

class ActionOption {
  final String label;
  final String value;

  ActionOption({required this.label, required this.value});

  factory ActionOption.fromJson(Map<String, dynamic> json) =>
      ActionOption(label: json['label'] as String, value: json['value'] as String);
}

class ActionRequired {
  final String prompt;
  final List<ActionOption> options;

  ActionRequired({required this.prompt, required this.options});

  factory ActionRequired.fromJson(Map<String, dynamic> json) => ActionRequired(
        prompt: json['prompt'] as String,
        options: (json['options'] as List).map((o) => ActionOption.fromJson(o)).toList(),
      );
}
