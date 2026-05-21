enum DebtStatus { active, paid, hidden }

extension DebtStatusX on DebtStatus {
  String get wire => name;
  static DebtStatus fromWire(String? raw) =>
      DebtStatus.values.firstWhere((e) => e.name == raw, orElse: () => DebtStatus.active);
}

class Debt {
  final String id;
  final String userId;
  final String name;
  final double totalAmount;
  final int numberOfInstallments;
  final DateTime dueDate;
  final String syncStatus;
  final String? updatedAt;
  final String? createdAt;
  final DebtStatus status;

  Debt({
    required this.id,
    required this.userId,
    required this.name,
    required this.totalAmount,
    required this.numberOfInstallments,
    required this.dueDate,
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
    this.status = DebtStatus.active,
  });

  double get amountPerInstallment =>
      numberOfInstallments > 0 ? totalAmount / numberOfInstallments : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'total_amount': totalAmount,
        'number_of_installments': numberOfInstallments,
        'due_date': dueDate.toIso8601String(),
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
        'status': status.wire,
      };

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      numberOfInstallments: json['number_of_installments'] as int,
      dueDate: DateTime.parse(json['due_date'] as String),
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
      status: DebtStatusX.fromWire(json['status'] as String?),
    );
  }
}
