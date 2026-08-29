enum FulfillmentType { none, delivery, pickup }

class Fulfillment {
  final FulfillmentType type;
  final String? address; // only used when type == delivery

  const Fulfillment({this.type = FulfillmentType.none, this.address});

  const Fulfillment.none() : this(type: FulfillmentType.none, address: null);

  Fulfillment copyWith({FulfillmentType? type, String? address}) => Fulfillment(
        type: type ?? this.type,
        address: type == FulfillmentType.delivery ? (address ?? this.address) : null,
      );

  bool get isChosen => type != FulfillmentType.none;

  bool get isReadyForReview {
    if (!isChosen) return false;
    if (type == FulfillmentType.delivery) {
      return (address ?? '').trim().length >= 5;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'address': address,
      };

  factory Fulfillment.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Fulfillment.none();
    return Fulfillment(
      type: FulfillmentType.values.firstWhere(
        (t) => t.name == j['type'],
        orElse: () => FulfillmentType.none,
      ),
      address: j['address'] as String?,
    );
  }
}
