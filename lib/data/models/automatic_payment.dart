class AutomaticPayment {
  final String id;
  final String userId;
  final String paymentType; // 'credit_card' | 'payment_method'
  final String paymentRef;
  final double amount;
  final String description;
  final DateTime nextRunDate;
  final String syncStatus;
  final String? updatedAt;
  final String? createdAt;

  AutomaticPayment({
    required this.id,
    required this.userId,
    required this.paymentType,
    required this.paymentRef,
    required this.amount,
    required this.description,
    required this.nextRunDate,
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'payment_type': paymentType,
        'payment_ref': paymentRef,
        'amount': amount,
        'description': description,
        'next_run_date': nextRunDate.toIso8601String(),
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
      };

  factory AutomaticPayment.fromJson(Map<String, dynamic> json) {
    return AutomaticPayment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      paymentType: json['payment_type'] as String,
      paymentRef: json['payment_ref'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      nextRunDate: DateTime.parse(json['next_run_date'] as String),
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
