import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/cart_line.dart';
import '../../../data/models/discount.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/discounts_repository.dart';
import '../../../data/repositories/orders_repository.dart';
import '../../cart/models/fulfillment.dart';
import '../../cart/providers/cart_controller.dart';
import '../../notifications/providers/notifications_providers.dart';
import '../../profile/screens/addresses_screen.dart';

enum PaymentMethod { none, cash, applePay }

enum CheckoutStage { idle, submitting, awaitingGateway, confirmed, failed }

class CheckoutState {
  final PaymentMethod paymentMethod;
  final String customerName;
  final String customerPhone;
  final int pointsToRedeem; // E5 — set from the review-screen redeem widget
  final DiscountPreview? discountPreview; // E6 — set once a code has been applied
  final String? discountError; // E6 — Arabic message shown under the code field
  final String? notes; // Stitch _5 — kitchen/driver note the customer types
  final CheckoutStage stage;
  final String? error;

  const CheckoutState({
    // Default to cash-on-delivery so the customer isn't blocked by an
    // unselected payment method — most orders finish on COD in KSA MVP,
    // and Apple Pay users can still switch via the picker.
    this.paymentMethod = PaymentMethod.cash,
    this.customerName = '',
    this.customerPhone = '',
    this.pointsToRedeem = 0,
    this.discountPreview,
    this.discountError,
    this.notes,
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
    String? notes,
    bool clearNotes = false,
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
        notes: clearNotes ? null : (notes ?? this.notes),
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

  /// Stitch _5 — customer-typed kitchen / driver notes.
  /// Empty or whitespace-only input clears the field so a stale note
  /// from a previous cart doesn't ride along to the next order.
  void setNotes(String? v) {
    final trimmed = (v ?? '').trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(clearNotes: true, clearError: true);
    } else {
      state = state.copyWith(notes: trimmed, clearError: true);
    }
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

    var cart = _ref.read(cartControllerProvider);
    // Auto-fill the delivery address from the customer's default saved
    // address when: fulfillment is delivery and the cart has no address
    // typed yet. Backend rejects delivery orders without a >=5-char
    // address, and there's no visible field on the review screen for
    // signed-in customers to fix that from — so we quietly pull the
    // default before the request even leaves the device.
    if (cart.fulfillment.type == FulfillmentType.delivery &&
        (cart.fulfillment.address == null || cart.fulfillment.address!.trim().length < 5)) {
      final addrs = _ref.read(savedAddressesProvider).valueOrNull ?? const [];
      if (addrs.isNotEmpty) {
        final def = addrs.firstWhere((a) => a.isDefault, orElse: () => addrs.first);
        _ref.read(cartControllerProvider.notifier).setFulfillment(
              FulfillmentType.delivery,
              address: def.addressText,
            );
        cart = _ref.read(cartControllerProvider);
      }
    }
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
      // Surface the server's actual message when the failure is an HTTP
      // response with a JSON body (Flask's error handlers emit
      // `{error, message}`) — the previous generic "حاول مجدداً" text
      // gave the customer no clue whether the problem was a missing
      // address, a coupon rejection, or the network.
      String msg = 'تعذّر إنشاء الطلب — حاول مجدداً';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] is String) {
          msg = (data['message'] as String).trim();
        } else if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          msg = 'لا يوجد اتصال بالخادم — تحقق من الإنترنت وحاول مجدداً';
        }
      }
      state = state.copyWith(stage: CheckoutStage.failed, error: msg);
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
      // Stitch _5 — kitchen / driver note is optional; sent verbatim.
      if (state.notes != null && state.notes!.isNotEmpty) 'notes': state.notes,
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
