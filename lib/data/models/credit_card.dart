class CreditCard {
  final String id;
  final String userId;
  final String alias;
  final int cutOffDay;
  final double managementFee;
  final bool isActive;
  final String syncStatus;
  final String? updatedAt;
  final String? createdAt;

  CreditCard({
    required this.id,
    required this.userId,
    required this.alias,
    required this.cutOffDay,
    required this.managementFee,
    this.isActive = true,
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'alias': alias,
        'cut_off_day': cutOffDay,
        'management_fee': managementFee,
        'is_active': isActive,
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
      };

  factory CreditCard.fromJson(Map<String, dynamic> json) {
    return CreditCard(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      alias: json['alias'] as String,
      cutOffDay: json['cut_off_day'] as int,
      managementFee: (json['management_fee'] as num).toDouble(),
      isActive: _parseIsActive(json['is_active']),
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  static bool _parseIsActive(dynamic raw) {
    if (raw == null) return true;
    if (raw is bool) return raw;
    if (raw is int) return raw == 1;
    return true;
  }

  CreditCard copyWith({
    String? id,
    String? userId,
    String? alias,
    int? cutOffDay,
    double? managementFee,
    bool? isActive,
    String? syncStatus,
    String? updatedAt,
    String? createdAt,
  }) {
    return CreditCard(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      alias: alias ?? this.alias,
      cutOffDay: cutOffDay ?? this.cutOffDay,
      managementFee: managementFee ?? this.managementFee,
      isActive: isActive ?? this.isActive,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
