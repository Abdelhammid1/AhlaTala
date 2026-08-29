/// Customer balance shape (E5).
class CustomerBalance {
  final int customerId;
  final String phone;
  final String? name;
  final int pointsBalance;

  const CustomerBalance({
    required this.customerId,
    required this.phone,
    this.name,
    required this.pointsBalance,
  });

  factory CustomerBalance.fromJson(Map<String, dynamic> j) => CustomerBalance(
        customerId: j['customer_id'] as int,
        phone: j['phone'] as String,
        name: j['name'] as String?,
        pointsBalance: (j['points_balance'] as num).toInt(),
      );
}

/// One ledger entry.
class LoyaltyLedgerEntry {
  final int id;
  final int delta;      // positive = earned; negative = redeemed
  final String reason;  // 'earned' | 'redeemed' | 'adjustment'
  final int? orderId;
  final String? note;
  final String? createdAt;

  const LoyaltyLedgerEntry({
    required this.id,
    required this.delta,
    required this.reason,
    this.orderId,
    this.note,
    this.createdAt,
  });

  factory LoyaltyLedgerEntry.fromJson(Map<String, dynamic> j) => LoyaltyLedgerEntry(
        id: j['id'] as int,
        delta: (j['delta'] as num).toInt(),
        reason: j['reason'] as String,
        orderId: j['order_id'] as int?,
        note: j['note'] as String?,
        createdAt: j['created_at'] as String?,
      );

  String get reasonAr => switch (reason) {
        'earned' => 'كسب من طلب',
        'redeemed' => 'استبدال',
        'adjustment' => 'تعديل',
        _ => reason,
      };
}
