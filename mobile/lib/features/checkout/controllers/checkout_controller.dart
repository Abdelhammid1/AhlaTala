import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/cart_line.dart';
import '../../../data/models/discount.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/discounts_repository.dart';
import '../../../data/repositories/orders_repository.dart';
import '../../cart/models/fulfillment.dart';
import '../../cart/providers/cart_controller.dart';
import '../../notifications/providers/notifications_providers.dart';

enum PaymentMethod { none, cash, applePay }

enum CheckoutStage { idle, submitting, awaitingGateway, confirmed, failed }

class CheckoutState {
  final PaymentMethod paymentMethod;
  final String customerName;
  final String customerPhone;
  final int pointsToRedeem; // E5 — set from the review-screen redeem widget
  final DiscountPreview? discountPreview; // E6 — set once a code has been applied
  final String? discountError; // E6 — Arabic message shown under the code field
  final CheckoutStage stage;
  final String? error;

  const CheckoutState({
    this.paymentMethod = PaymentMethod.none,
    this.customerName = '',
    this.customerPhone = '',
    this.pointsToRedeem = 0,
    this.discountPreview,
    this.discountError,
    this.stage = CheckoutStage.idle,
    this.error,
  });

  CheckoutState copyWith({
    PaymentMethod? paymentMethod,
    String? customerName,
    String? customerPhone,
    int? pointsToRedeem,
    DiscountPreview? discountPreview,
    String? discountError,
    bool clearDiscount = false,
    CheckoutStage? stage,
    String? error,
    bool clearError = false,
  }) =>
      CheckoutState(
        paymentMethod: paymentMethod ?? this.paymentMethod,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        pointsToRedeem: pointsToRedeem ?? this.pointsToRedeem,
        discountPreview: clearDiscount ? null : (discountPreview ?? this.discountPreview),
        discountError: clearDiscount ? null : (discountError ?? this.discountError),
        stage: stage ?? this.stage,
        error: clearError ? null : (error ?? this.error),
      );

  bool get canSubmit =>
      paymentMethod != PaymentMethod.none &&
      customerName.trim().length >= 2 &&
      customerPhone.trim().length >= 4 &&
      stage != CheckoutStage.submitting &&
      stage != CheckoutStage.awaitingGateway;

  String get missingHint {
    if (paymentMethod == PaymentMethod.none) return 'اختر طريقة الدفع';
    if (customerName.trim().length < 2) return 'أدخل الاسم';
    if (customerPhone.trim().length < 4) return 'أدخل رقم الجوال';
    return '';
  }
}

class CheckoutController extends StateNotifier<CheckoutState> {
  CheckoutController(this._ref) : super(const CheckoutState());

  final Ref _ref;

  void setPaymentMethod(PaymentMethod m) => state = state.copyWith(paymentMethod: m, clearError: true);
  void setCustomerName(String v) => state = state.copyWith(customerName: v, clearError: true);
  void setCustomerPhone(String v) => state = state.copyWith(customerPhone: v, clearError: true);
  void setPointsToRedeem(int p) {
    if (p == state.pointsToRedeem) return;
    state = state.copyWith(pointsToRedeem: p, clearError: true);
  }

  /// Try to apply a discount code — hits the preview endpoint so we can show
  /// success/error immediately (no need to wait for order submission).
  /// `pointsDiscount` is the money value of the current loyalty redemption
  /// (0 if no points are being redeemed); the server needs it so a percent
  /// code applies to the post-points subtotal, matching `create_order`.
  Future<void> applyDiscountCode(
    String code, {
    required double subtotal,
    double pointsDiscount = 0,
  }) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      clearDiscountCode();
      return;
    }
    final res = await _ref.read(discountsRepositoryProvider).preview(
          code: trimmed,
          subtotal: subtotal,
          pointsDiscount: pointsDiscount,
        );
    if (res.ok) {
      state = state.copyWith(
        discountPreview: res.preview,
        discountError: null,
      );
    } else {
      state = state.copyWith(
        clearDiscount: true,
        discountError: res.errorMessage,
      );
    }
  }

  void clearDiscountCode() {
    if (state.discountPreview == null && state.discountError == null) return;
    state = state.copyWith(clearDiscount: true);
  }

  void reset() => state = const CheckoutState();

  /// Submit the cart as an order. Returns the create response on success,
  /// null on failure (error message set on state).
  Future<OrderCreateResp?> submit() async {
    if (!state.canSubmit) return null;
    state = state.copyWith(stage: CheckoutStage.submitting, clearError: true);

    final cart = _ref.read(cartControllerProvider);
    final body = _buildRequestBody(cart);

    try {
      final resp = await _ref.read(ordersRepositoryProvider).createOrder(body);
      final gatewayFlow = resp.paymentStatus == 'redirect';
      state = state.copyWith(
        stage: gatewayFlow ? CheckoutStage.awaitingGateway : CheckoutStage.confirmed,
      );
      // Remember this phone for the inbox + future auto-fill (E8).
      _ref.read(savedPhoneProvider.notifier).save(state.customerPhone);
      return resp;
    } catch (e) {
      state = state.copyWith(stage: CheckoutStage.failed, error: 'تعذّر إنشاء الطلب — حاول مجدداً');
      return null;
    }
  }

  Map<String, dynamic> _buildRequestBody(CartState cart) {
    return {
      'customer_name': state.customerName.trim(),
      'customer_phone': state.customerPhone.trim(),
      'fulfillment_type': cart.fulfillment.type == FulfillmentType.delivery ? 'delivery' : 'pickup',
      if (cart.fulfillment.type == FulfillmentType.delivery)
        'delivery_address': cart.fulfillment.address,
      'payment_method': switch (state.paymentMethod) {
        PaymentMethod.cash => 'cash',
        PaymentMethod.applePay => 'apple_pay',
        _ => 'cash',
      },
      if (state.pointsToRedeem > 0) 'points_to_redeem': state.pointsToRedeem,
      if (state.discountPreview != null) 'discount_code': state.discountPreview!.code,
      'lines': [
        for (final CartLine l in cart.lines)
          {
            'item_id': l.itemId,
            'quantity': l.quantity,
            'selections': [
              for (final s in l.selections)
                {'group_id': s.groupId, 'option_id': s.optionId},
            ],
          }
      ],
    };
  }
}

final checkoutControllerProvider =
    StateNotifierProvider<CheckoutController, CheckoutState>((ref) {
  return CheckoutController(ref);
});
