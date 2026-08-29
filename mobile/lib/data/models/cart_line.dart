import 'package:uuid/uuid.dart';

/// One selected option on a cart line, snapshot at add-time.
/// Kept flat + primitive so JSON persistence is trivial.
class CartLineSelection {
  final int groupId;
  final String groupNameAr;
  final String groupKind; // 'variant' | 'size' | 'remove' | 'add'
  final int optionId;
  final String optionNameAr;
  final double priceDelta;

  const CartLineSelection({
    required this.groupId,
    required this.groupNameAr,
    required this.groupKind,
    required this.optionId,
    required this.optionNameAr,
    required this.priceDelta,
  });

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'group_name_ar': groupNameAr,
        'group_kind': groupKind,
        'option_id': optionId,
        'option_name_ar': optionNameAr,
        'price_delta': priceDelta,
      };

  factory CartLineSelection.fromJson(Map<String, dynamic> j) => CartLineSelection(
        groupId: j['group_id'] as int,
        groupNameAr: j['group_name_ar'] as String,
        groupKind: j['group_kind'] as String,
        optionId: j['option_id'] as int,
        optionNameAr: j['option_name_ar'] as String,
        priceDelta: (j['price_delta'] as num).toDouble(),
      );
}

/// One line in the cart. Everything about the item is snapshotted at add-time
/// so admin changes to the source item don't retroactively edit the customer's
/// cart. Line prices are computed from the snapshot.
class CartLine {
  final String id;
  final int itemId;
  final String nameAr;
  final String? imageUrl;
  final double basePrice;
  final List<CartLineSelection> selections;
  final int quantity;

  const CartLine({
    required this.id,
    required this.itemId,
    required this.nameAr,
    this.imageUrl,
    required this.basePrice,
    required this.selections,
    required this.quantity,
  });

  factory CartLine.newLine({
    required int itemId,
    required String nameAr,
    String? imageUrl,
    required double basePrice,
    required List<CartLineSelection> selections,
    int quantity = 1,
  }) =>
      CartLine(
        id: const Uuid().v4(),
        itemId: itemId,
        nameAr: nameAr,
        imageUrl: imageUrl,
        basePrice: basePrice,
        selections: selections,
        quantity: quantity,
      );

  double get unitPrice =>
      basePrice + selections.fold<double>(0.0, (acc, s) => acc + s.priceDelta);

  double get linePrice => unitPrice * quantity;

  CartLine copyWith({int? quantity}) => CartLine(
        id: id,
        itemId: itemId,
        nameAr: nameAr,
        imageUrl: imageUrl,
        basePrice: basePrice,
        selections: selections,
        quantity: quantity ?? this.quantity,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'name_ar': nameAr,
        'image_url': imageUrl,
        'base_price': basePrice,
        'selections': selections.map((s) => s.toJson()).toList(),
        'quantity': quantity,
      };

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        id: j['id'] as String,
        itemId: j['item_id'] as int,
        nameAr: j['name_ar'] as String,
        imageUrl: j['image_url'] as String?,
        basePrice: (j['base_price'] as num).toDouble(),
        selections: (j['selections'] as List)
            .map((s) => CartLineSelection.fromJson(s as Map<String, dynamic>))
            .toList(),
        quantity: (j['quantity'] as num).toInt(),
      );
}
