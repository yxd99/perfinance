/// Payment mirrored from a creditor's receivable_payment.
/// Deliberately has NO note field — the creditor's private notes are never
/// surfaced to the debtor.
class MirroredDebtPayment {
  final String id;
  final String mirroredDebtId;
  final double amount;
  final DateTime date;
  final String? createdAt;

  const MirroredDebtPayment({
    required this.id,
    required this.mirroredDebtId,
    required this.amount,
    required this.date,
    this.createdAt,
  });

  factory MirroredDebtPayment.fromJson(Map<String, dynamic> json) {
    return MirroredDebtPayment(
      id: json['id'] as String,
      mirroredDebtId: json['mirrored_debt_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mirrored_debt_id': mirroredDebtId,
        'amount': amount,
        'date': date.toIso8601String(),
        'created_at': createdAt,
      };
}
