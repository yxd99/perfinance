class MinPaymentConfig {
  final String id;
  final String cardId;
  final double amount;
  final int year;
  final int month;
  final String syncStatus;
  final String? updatedAt;
  final String? createdAt;

  MinPaymentConfig({
    required this.id,
    required this.cardId,
    required this.amount,
    required this.year,
    required this.month,
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'card_id': cardId,
        'amount': amount,
        'year': year,
        'month': month,
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
      };

  factory MinPaymentConfig.fromJson(Map<String, dynamic> json) {
    return MinPaymentConfig(
      id: json['id'] as String,
      cardId: json['card_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      year: json['year'] as int,
      month: json['month'] as int,
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
