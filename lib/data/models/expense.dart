class Expense {
  final String id;
  final String userId;
  final double amount;
  final DateTime date;
  final String paymentType; // 'credit_card' | 'payment_method'
  final String paymentRef;
  final String? description;
  final String syncStatus;
  final String? updatedAt;
  final String? createdAt;

  Expense({
    required this.id,
    required this.userId,
    required this.amount,
    required this.date,
    required this.paymentType,
    required this.paymentRef,
    this.description,
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'amount': amount,
        'date': date.toIso8601String(),
        'payment_type': paymentType,
        'payment_ref': paymentRef,
        'description': description,
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
      };

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      paymentType: json['payment_type'] as String,
      paymentRef: json['payment_ref'] as String,
      description: json['description'] as String?,
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Expense copyWith({
    String? id,
    String? userId,
    double? amount,
    DateTime? date,
    String? paymentType,
    String? paymentRef,
    required String? description,
    String? syncStatus,
    String? updatedAt,
    String? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentType: paymentType ?? this.paymentType,
      paymentRef: paymentRef ?? this.paymentRef,
      description: description,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
