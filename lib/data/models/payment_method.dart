class PaymentMethod {
  final String id;
  final String userId;
  final String name;
  final String type;

  /// Posición en la paleta de billetes elegida por el usuario; null = automático.
  final int? colorSlot;
  final String syncStatus;
  final String? updatedAt;
  final String? createdAt;

  PaymentMethod({
    required this.id,
    required this.userId,
    required this.name,
    this.type = 'other',
    this.colorSlot,
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'type': type,
        'color_slot': colorSlot,
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
      };

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'other',
      colorSlot: (json['color_slot'] as num?)?.toInt(),
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  PaymentMethod copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    int? colorSlot,
    String? syncStatus,
    String? updatedAt,
    String? createdAt,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      colorSlot: colorSlot ?? this.colorSlot,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
