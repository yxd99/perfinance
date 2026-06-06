enum ReceivableStatus { active, settled, writtenOff, hidden }

extension ReceivableStatusX on ReceivableStatus {
  String get wire => switch (this) {
        ReceivableStatus.writtenOff => 'written_off',
        _ => name,
      };

  static ReceivableStatus fromWire(String? raw) => switch (raw) {
        'settled' => ReceivableStatus.settled,
        'written_off' => ReceivableStatus.writtenOff,
        'hidden' => ReceivableStatus.hidden,
        _ => ReceivableStatus.active,
      };
}

class Receivable {
  final String id;
  final String userId;
  final String debtorName;
  final String? debtorEmail;
  final double totalAmount;
  final String? description;
  final DateTime? dueDate;
  final ReceivableStatus status;
  final String syncStatus;
  final String? updatedAt;
  final String? createdAt;

  Receivable({
    required this.id,
    required this.userId,
    required this.debtorName,
    this.debtorEmail,
    required this.totalAmount,
    this.description,
    this.dueDate,
    this.status = ReceivableStatus.active,
    this.syncStatus = 'synced',
    this.updatedAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'debtor_name': debtorName,
        'debtor_email': debtorEmail,
        'total_amount': totalAmount,
        'description': description,
        'due_date': dueDate?.toIso8601String(),
        'status': status.wire,
        'sync_status': syncStatus,
        'updated_at': updatedAt,
        'created_at': createdAt,
      };

  factory Receivable.fromJson(Map<String, dynamic> json) {
    return Receivable(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      debtorName: json['debtor_name'] as String,
      debtorEmail: json['debtor_email'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      description: json['description'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      status: ReceivableStatusX.fromWire(json['status'] as String?),
      syncStatus: json['sync_status'] as String? ?? 'synced',
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
