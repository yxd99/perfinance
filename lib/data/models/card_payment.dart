class CardPayment {
  final String id;
  final String cardId;
  final double amount;
  final DateTime date;
  final String syncStatus;
  final String? updatedAt;
  final String? createdAt;

  CardPayment({
    required this.id,
    required this.cardId,
    required this.amount,
    required this.date,
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'card_id': cardId,
        'amount': amount,
        'date': date.toIso8601String(),
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
      };

  factory CardPayment.fromJson(Map<String, dynamic> json) {
    return CardPayment(
      id: json['id'] as String,
      cardId: json['card_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
