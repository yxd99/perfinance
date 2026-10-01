class ChatConversation {
  final String id;
  final String userId;
  final String agentType;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatConversation({
    required this.id,
    required this.userId,
    required this.agentType,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) => ChatConversation(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        agentType: json['agent_type'] as String,
        title: json['title'] as String? ?? 'Chat',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'agent_type': agentType,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ChatConversation copyWith({String? title, DateTime? updatedAt}) => ChatConversation(
        id: id,
        userId: userId,
        agentType: agentType,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
