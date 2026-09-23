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

/// One row of `saved_addresses`.
///
/// The Stitch _3 form (add-address) writes into the extended fields below;
/// they're all nullable so pre-Stitch rows and address-lite creations
/// (e.g. a legacy admin-import row that only has label + free-form text)
/// still parse cleanly. `labelType` is one of home/office/hotel/rest/other,
/// or null when the row predates the typed picker.
class SavedAddress {
  final int id;
  final String label;
  final String addressText;
  final bool isDefault;
  final int sortOrder;

  // ---- Stitch _3 extended fields ----
  final String? labelType;
  final String? districtName;
  final String? aptNumber;
  final String? floor;
  final String? extraDetails;
  final String? contactPhone;
  final bool leaveAtDoor;
  final bool dontRingBell;
  final String? photoUrl;
  final double? lat;
  final double? lng;
  final String? formattedAddress;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.addressText,
    required this.isDefault,
    required this.sortOrder,
    this.labelType,
    this.districtName,
    this.aptNumber,
    this.floor,
    this.extraDetails,
    this.contactPhone,
    this.leaveAtDoor = false,
    this.dontRingBell = false,
    this.photoUrl,
    this.lat,
    this.lng,
    this.formattedAddress,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        id: j['id'] as int,
        label: j['label'] as String,
        addressText: j['address_text'] as String,
        isDefault: (j['is_default'] as bool?) ?? false,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        labelType: j['label_type'] as String?,
        districtName: j['district_name'] as String?,
        aptNumber: j['apt_number'] as String?,
        floor: j['floor'] as String?,
        extraDetails: j['extra_details'] as String?,
        contactPhone: j['contact_phone'] as String?,
        leaveAtDoor: (j['leave_at_door'] as bool?) ?? false,
        dontRingBell: (j['dont_ring_bell'] as bool?) ?? false,
        photoUrl: j['photo_url'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        formattedAddress: j['formatted_address'] as String?,
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
