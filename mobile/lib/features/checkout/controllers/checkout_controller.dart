import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/cart_line.dart';
import '../../../data/models/discount.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/discounts_repository.dart';
import '../../../data/repositories/orders_repository.dart';
import '../../../data/models/session.dart';
import '../../auth/controllers/auth_controller.dart';
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
    // Late-hydrate name/phone from the auth session in case the user
    // taps the CTA before CustomerForm's post-frame seeding runs. Same
    // fallback as the form ('عميل' when session name is empty), so the
    // canSubmit check doesn't reject a signed-in customer just because
    // the state hasn't caught up to the widget.
    final session = _ref.read(authControllerProvider);
    if (session != null) {
      if (state.customerName.trim().length < 2) {
        final n = (session.customer.name ?? '').trim();
        state = state.copyWith(customerName: n.isEmpty ? 'عميل' : n);
      }
      if (state.customerPhone.trim().length < 4) {
        state = state.copyWith(customerPhone: session.customer.phone);
      }
    }
    if (!state.canSubmit) {
      // Never return silently — surface the specific missing piece so
      // the customer knows why the button didn't move them forward.
      state = state.copyWith(stage: CheckoutStage.failed, error: state.missingHint);
      return null;
    }
    state = state.copyWith(stage: CheckoutStage.submitting, clearError: true);

    var cart = _ref.read(cartControllerProvider);
    // Backend rejects delivery orders without a >=5-char address, and
    // the review screen doesn't show an address field for signed-in
    // customers — so we auto-pull the default saved address whenever
    // the cart's is missing. Use `.future` (not `.valueOrNull`) so an
    // autoDispose'd provider hydrates on the spot rather than returning
    // null and falling through to the same 'address required' error.
    final needsDeliveryAddress = cart.fulfillment.type == FulfillmentType.delivery &&
        (cart.fulfillment.address == null || cart.fulfillment.address!.trim().length < 5);
    // Signed-in guest with no explicit fulfillment yet? Default to
    // delivery when they have a saved address — the UI defaults visually
    // to delivery on the home fulfillment toggle, so this matches
    // customer expectation. Otherwise pickup, which needs no address.
    final unresolvedFulfillment = cart.fulfillment.type == FulfillmentType.none;
    if (needsDeliveryAddress || unresolvedFulfillment) {
      List<SavedAddress> addrs = const [];
      if (session != null) {
        try {
          addrs = await _ref.read(savedAddressesProvider.future);
        } catch (_) {
          addrs = const [];
        }
      }
      if (addrs.isNotEmpty) {
        final def = addrs.firstWhere((a) => a.isDefault, orElse: () => addrs.first);
        // Compose a full delivery-ready address string. Backend rejects
        // anything under 5 chars, and legacy rows sometimes have a
        // super-short addressText (e.g. just "منزل"), so we join every
        // field we have on the SavedAddress until it's long enough.
        final composed = _composeDeliveryAddress(def);
        if (composed.length >= 5) {
          _ref.read(cartControllerProvider.notifier).setFulfillment(
                FulfillmentType.delivery,
                address: composed,
              );
          cart = _ref.read(cartControllerProvider);
        } else if (needsDeliveryAddress) {
          state = state.copyWith(
            stage: CheckoutStage.failed,
            error: 'عنوان التوصيل غير مكتمل — عدّله من "عناويني" وأضف تفاصيل الحي والشارع',
          );
          return null;
        } else {
          // Unresolved fulfillment + short address → safer to fall back
          // to pickup than to send an invalid delivery request.
          _ref.read(cartControllerProvider.notifier).setFulfillment(FulfillmentType.pickup);
          cart = _ref.read(cartControllerProvider);
        }
      } else if (needsDeliveryAddress) {
        // Delivery was chosen but no saved address exists to fall back
        // to → point the customer at the address form instead of firing
        // a request the server will only reject.
        state = state.copyWith(
          stage: CheckoutStage.failed,
          error: 'أضف عنوان توصيل من "عناويني" قبل إتمام الطلب',
        );
        return null;
      } else {
        // No preference, no saved address → pickup is the safe default.
        _ref.read(cartControllerProvider.notifier).setFulfillment(FulfillmentType.pickup);
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
      // Surface the most specific message we can. Priority:
      //   1. Server JSON `message` or `details` (Flask validation errors)
      //   2. HTTP status line ('HTTP 422' etc.)
      //   3. Network subtype ('لا يوجد اتصال بالخادم')
      //   4. Raw exception text with type prefix (last-ditch diagnostic)
      String msg = 'تعذّر إنشاء الطلب — حاول مجدداً';
      if (e is DioException) {
        final data = e.response?.data;
        String? extracted;
        if (data is Map) {
          if (data['message'] is String) extracted = (data['message'] as String).trim();
          // Flask ValidationError puts field-level messages in `details`.
          extracted ??= data['details'] is String
              ? (data['details'] as String).trim()
              : (data['details'] != null ? data['details'].toString() : null);
          extracted ??= data['error'] is String ? (data['error'] as String).trim() : null;
        } else if (data is String && data.isNotEmpty) {
          extracted = data;
        }
        if (extracted != null && extracted.isNotEmpty) {
          msg = extracted;
        } else if (e.response?.statusCode != null) {
          msg = 'الخادم رفض الطلب (HTTP ${e.response!.statusCode})';
        } else if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          msg = 'لا يوجد اتصال بالخادم — تحقق من الإنترنت وحاول مجدداً';
        } else {
          msg = 'شبكة: ${e.message ?? e.type.name}';
        }
      } else {
        // Non-Dio exception (json parse, state error, …) — show its type
        // so we can chase it down instead of hiding behind a generic line.
        msg = '${e.runtimeType}: $e';
      }
      state = state.copyWith(stage: CheckoutStage.failed, error: msg);
      return null;
    }
  }

  /// Squeeze every readable field on a SavedAddress into one comma-
  /// separated line the backend + driver both understand. Order goes
  /// widest-context → narrowest so the string is scannable
  /// (formatted → district → street/apt/floor → free-form → label).
  /// Duplicates are dropped so nothing repeats when the customer put
  /// the same info in multiple fields.
  String _composeDeliveryAddress(SavedAddress a) {
    final seen = <String>{};
    final parts = <String>[];
    void push(String? v) {
      if (v == null) return;
      final t = v.trim();
      if (t.isEmpty) return;
      if (seen.add(t)) parts.add(t);
    }
    push(a.formattedAddress);
    push(a.districtName != null && a.districtName!.trim().isNotEmpty ? 'حي ${a.districtName!.trim()}' : null);
    push(a.aptNumber != null && a.aptNumber!.trim().isNotEmpty ? 'شقة ${a.aptNumber!.trim()}' : null);
    push(a.floor != null && a.floor!.trim().isNotEmpty ? 'الطابق ${a.floor!.trim()}' : null);
    push(a.extraDetails);
    push(a.addressText);
    push(a.label);
    return parts.join('، ');
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
