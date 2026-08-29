/// Arabic labels for every order status the API can return (E3 + E4).
/// Kept top-level so both the confirmation screen header and the timeline
/// widget use the same source of truth.
String orderStatusAr(String status) {
  switch (status) {
    case 'created':
      return 'قيد التأكيد';
    case 'confirmed':
      return 'مؤكد';
    case 'preparing':
      return 'قيد التجهيز';
    case 'on_the_way':
      return 'في الطريق';
    case 'ready_for_pickup':
      return 'جاهز للاستلام';
    case 'delivered':
      return 'تم التسليم';
    case 'cancelled':
      return 'ملغى';
    case 'failed':
      return 'فشل الدفع';
    default:
      return status;
  }
}

/// Terminal (no further transitions expected) — mobile stops polling when true.
bool isTerminalOrderStatus(String status) =>
    status == 'delivered' || status == 'cancelled' || status == 'failed';

/// Shapes for the E3 orders API (mirrors backend order_schemas.py).
class OrderLineSelectionResp {
  final int groupId;
  final String groupNameAr;
  final String groupKind;
  final int optionId;
  final String optionNameAr;
  final double priceDelta;

  const OrderLineSelectionResp({
    required this.groupId,
    required this.groupNameAr,
    required this.groupKind,
    required this.optionId,
    required this.optionNameAr,
    required this.priceDelta,
  });

  factory OrderLineSelectionResp.fromJson(Map<String, dynamic> j) =>
      OrderLineSelectionResp(
        groupId: j['group_id'] as int,
        groupNameAr: j['group_name_ar'] as String,
        groupKind: j['group_kind'] as String,
        optionId: j['option_id'] as int,
        optionNameAr: j['option_name_ar'] as String,
        priceDelta: _n(j['price_delta']),
      );
}

class OrderLineResp {
  final int id;
  final int? itemId;
  final String nameAr;
  final String? imageUrl;
  final double basePrice;
  final int quantity;
  final double unitPrice;
  final double linePrice;
  final int sortOrder;
  final List<OrderLineSelectionResp> selections;

  const OrderLineResp({
    required this.id,
    this.itemId,
    required this.nameAr,
    this.imageUrl,
    required this.basePrice,
    required this.quantity,
    required this.unitPrice,
    required this.linePrice,
    required this.sortOrder,
    required this.selections,
  });

  factory OrderLineResp.fromJson(Map<String, dynamic> j) => OrderLineResp(
        id: j['id'] as int,
        itemId: j['item_id'] as int?,
        nameAr: j['name_ar'] as String,
        imageUrl: j['image_url'] as String?,
        basePrice: _n(j['base_price']),
        quantity: (j['quantity'] as num).toInt(),
        unitPrice: _n(j['unit_price']),
        linePrice: _n(j['line_price']),
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        selections: ((j['selections'] as List?) ?? const [])
            .map((e) => OrderLineSelectionResp.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OrderResp {
  final int id;
  final String? orderNumber;
  final String status; // created | confirmed | preparing | on_the_way | ready_for_pickup | delivered | cancelled | failed
  final String fulfillmentType; // delivery | pickup
  final String? deliveryAddress;
  final String customerName;
  final String customerPhone;
  final int? customerId;
  final double subtotal;
  final double deliveryFee;
  final double discountAmount; // E5+E6 (total)
  final double pointsDiscount; // E5
  final double codeDiscount;   // E6
  final String? discountCode;  // E6 (snapshot of code as typed)
  final double total;
  final int pointsRedeemed; // E5
  final int pointsEarned;   // E5 (only nonzero once delivered)
  final String paymentMethod; // cash | apple_pay | gateway_stub
  final String? paymentReference;
  final String? notes;
  final List<OrderLineResp> lines;

  const OrderResp({
    required this.id,
    this.orderNumber,
    required this.status,
    required this.fulfillmentType,
    this.deliveryAddress,
    required this.customerName,
    required this.customerPhone,
    this.customerId,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.pointsDiscount,
    required this.codeDiscount,
    this.discountCode,
    required this.total,
    required this.pointsRedeemed,
    required this.pointsEarned,
    required this.paymentMethod,
    this.paymentReference,
    this.notes,
    required this.lines,
  });

  factory OrderResp.fromJson(Map<String, dynamic> j) => OrderResp(
        id: j['id'] as int,
        orderNumber: j['order_number'] as String?,
        status: j['status'] as String,
        fulfillmentType: j['fulfillment_type'] as String,
        deliveryAddress: j['delivery_address'] as String?,
        customerName: j['customer_name'] as String,
        customerPhone: j['customer_phone'] as String,
        customerId: j['customer_id'] as int?,
        subtotal: _n(j['subtotal']),
        deliveryFee: _n(j['delivery_fee']),
        discountAmount: _n(j['discount_amount']),
        pointsDiscount: _n(j['points_discount']),
        codeDiscount: _n(j['code_discount']),
        discountCode: j['discount_code'] as String?,
        total: _n(j['total']),
        pointsRedeemed: (j['points_redeemed'] as num?)?.toInt() ?? 0,
        pointsEarned: (j['points_earned'] as num?)?.toInt() ?? 0,
        paymentMethod: j['payment_method'] as String,
        paymentReference: j['payment_reference'] as String?,
        notes: j['notes'] as String?,
        lines: ((j['lines'] as List?) ?? const [])
            .map((e) => OrderLineResp.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Result of POST /orders. Payment goes into a compact wrapper.
class OrderCreateResp {
  final OrderResp order;
  final String paymentStatus;   // confirmed | redirect | failed
  final String? redirectUrl;
  final String? reference;
  final String? message;

  const OrderCreateResp({
    required this.order,
    required this.paymentStatus,
    this.redirectUrl,
    this.reference,
    this.message,
  });

  factory OrderCreateResp.fromJson(Map<String, dynamic> j) {
    final pay = (j['payment'] as Map<String, dynamic>?) ?? const {};
    return OrderCreateResp(
      order: OrderResp.fromJson(j['order'] as Map<String, dynamic>),
      paymentStatus: (pay['status'] as String?) ?? 'failed',
      redirectUrl: pay['redirect_url'] as String?,
      reference: pay['reference'] as String?,
      message: pay['message'] as String?,
    );
  }
}

double _n(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}
