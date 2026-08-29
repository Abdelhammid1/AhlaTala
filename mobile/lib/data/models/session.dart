/// The signed-in user's identity + JWT.
class SessionCustomer {
  final int customerId;
  final String phone;
  final String? name;
  final int pointsBalance;
  final DateTime? verifiedAt;

  const SessionCustomer({
    required this.customerId,
    required this.phone,
    this.name,
    required this.pointsBalance,
    this.verifiedAt,
  });

  factory SessionCustomer.fromJson(Map<String, dynamic> j) => SessionCustomer(
        customerId: j['customer_id'] as int,
        phone: j['phone'] as String,
        name: j['name'] as String?,
        pointsBalance: (j['points_balance'] as num?)?.toInt() ?? 0,
        verifiedAt: j['verified_at'] is String
            ? DateTime.tryParse(j['verified_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'phone': phone,
        'name': name,
        'points_balance': pointsBalance,
        'verified_at': verifiedAt?.toIso8601String(),
      };
}

class SavedAddress {
  final int id;
  final String label;
  final String addressText;
  final bool isDefault;
  final int sortOrder;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.addressText,
    required this.isDefault,
    required this.sortOrder,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        id: j['id'] as int,
        label: j['label'] as String,
        addressText: j['address_text'] as String,
        isDefault: (j['is_default'] as bool?) ?? false,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class Session {
  final String token;
  final SessionCustomer customer;

  const Session({required this.token, required this.customer});

  Map<String, dynamic> toJson() => {'token': token, 'customer': customer.toJson()};

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        token: j['token'] as String,
        customer: SessionCustomer.fromJson(j['customer'] as Map<String, dynamic>),
      );
}
