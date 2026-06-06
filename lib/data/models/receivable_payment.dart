class ReceivablePayment {
  final String id;
  final String receivableId;
  final double amount;
  final DateTime date;
  final String? note;
  final String syncStatus;
  final String? updatedAt;
  final String? createdAt;

  ReceivablePayment({
    required this.id,
    required this.receivableId,
    required this.amount,
    required this.date,
    this.note,
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'receivable_id': receivableId,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
      };

  factory ReceivablePayment.fromJson(Map<String, dynamic> json) {
    return ReceivablePayment(
      id: json['id'] as String,
      receivableId: json['receivable_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
