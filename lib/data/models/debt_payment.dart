class DebtPayment {
  final String id;
  final String debtId;
  final double amount;
  final DateTime date;
  final String syncStatus;
  final String? updatedAt;
  final String? createdAt;

  DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'debt_id': debtId,
        'amount': amount,
        'date': date.toIso8601String(),
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
      };

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as String,
      debtId: json['debt_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
