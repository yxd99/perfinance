const _validFrequencies = {'mensual', 'trimestral', 'semestral', 'anual'};

class AutomaticPayment {
  final String id;
  final String userId;
  final String paymentType; // 'credit_card' | 'payment_method'
  final String paymentRef;
  final double amount;
  final String description;
  final DateTime nextRunDate;
  final int paymentDayOfMonth; // 1..31, fuente de verdad del día de pago
  final String frequency; // 'mensual'|'trimestral'|'semestral'|'anual'
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
    this.paymentDayOfMonth = 1,
    this.frequency = 'mensual',
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
  }) : assert(
          _validFrequencies.contains(frequency),
          'frequency debe ser mensual, trimestral, semestral o anual',
        );

  AutomaticPayment copyWith({
    String? id,
    String? userId,
    String? paymentType,
    String? paymentRef,
    double? amount,
    String? description,
    DateTime? nextRunDate,
    int? paymentDayOfMonth,
    String? frequency,
    String? syncStatus,
    String? updatedAt,
    String? createdAt,
  }) {
    return AutomaticPayment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      paymentType: paymentType ?? this.paymentType,
      paymentRef: paymentRef ?? this.paymentRef,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      nextRunDate: nextRunDate ?? this.nextRunDate,
      paymentDayOfMonth: paymentDayOfMonth ?? this.paymentDayOfMonth,
      frequency: frequency ?? this.frequency,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'payment_type': paymentType,
        'payment_ref': paymentRef,
        'amount': amount,
        'description': description,
        'next_run_date': nextRunDate.toIso8601String(),
        'payment_day_of_month': paymentDayOfMonth,
        'frequency': frequency,
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
      };

  factory AutomaticPayment.fromJson(Map<String, dynamic> json) {
    final nextRunDate = DateTime.parse(json['next_run_date'] as String);
    return AutomaticPayment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      paymentType: json['payment_type'] as String,
      paymentRef: json['payment_ref'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      nextRunDate: nextRunDate,
      paymentDayOfMonth: json['payment_day_of_month'] as int? ?? nextRunDate.day,
      frequency: json['frequency'] as String? ?? 'mensual',
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  factory AutomaticPayment.fromMap(Map<String, dynamic> map) {
    final nextRunDate = DateTime.parse(map['next_run_date'] as String);
    final rawFreq = map['frequency'] as String? ?? 'mensual';
    return AutomaticPayment(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      paymentType: map['payment_type'] as String,
      paymentRef: map['payment_ref'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      nextRunDate: nextRunDate,
      paymentDayOfMonth: map['payment_day_of_month'] as int? ?? nextRunDate.day,
      frequency: _validFrequencies.contains(rawFreq) ? rawFreq : 'mensual',
      syncStatus: map['sync_status'] as String? ?? 'synced',
      updatedAt: map['updated_at'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }
}
