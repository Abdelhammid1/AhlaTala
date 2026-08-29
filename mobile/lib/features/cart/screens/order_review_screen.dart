import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/cart_line.dart';
import '../../checkout/controllers/checkout_controller.dart';
import '../../checkout/widgets/customer_form.dart';
import '../../checkout/widgets/payment_method_picker.dart';
import '../../discounts/widgets/discount_code_section.dart';
import '../../loyalty/widgets/redeem_points_section.dart';
import '../providers/settings_provider.dart';
import '../models/fulfillment.dart';
import '../providers/cart_controller.dart';

/// Totals card with a live discount preview. Server is the authority — this is UI only.
class _TotalsCard extends ConsumerWidget {
  const _TotalsCard({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.fulfillment,
    required this.pointsToRedeem,
    required this.codeDiscount,
    this.codeName,
  });
  final double subtotal;
  final double deliveryFee;
  final double total;
  final FulfillmentType fulfillment;
  final int pointsToRedeem;
  final double codeDiscount;
  final String? codeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => AppSettings.fallback(),
        );
    final pointsDiscount = pointsToRedeem * settings.riyalPerPoint;
    final adjustedTotal = total - pointsDiscount - codeDiscount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _row('المجموع الفرعي', subtotal),
            if (fulfillment == FulfillmentType.delivery)
              _row('رسوم التوصيل', deliveryFee),
            if (pointsDiscount > 0)
              _row('خصم النقاط ($pointsToRedeem)', -pointsDiscount, tint: Colors.green.shade700),
            if (codeDiscount > 0)
              _row('خصم كود${codeName != null ? " ($codeName)" : ""}', -codeDiscount, tint: Colors.green.shade700),
            const Divider(),
            _row('الإجمالي', adjustedTotal, emphasize: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool emphasize = false, Color? tint}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: tint,
                      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
                      fontSize: emphasize ? 16 : 14))),
          Text('${value.toStringAsFixed(2)} ريال',
              style: TextStyle(
                  color: tint,
                  fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
                  fontSize: emphasize ? 16 : 14)),
        ]),
      );
}

/// US2.5 — full order review + E3 payment flow.
class OrderReviewScreen extends ConsumerWidget {
  const OrderReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartControllerProvider);
    final subtotal = state.subtotal;
    final deliveryFee = ref.watch(cartDeliveryFeeProvider);
    final total = ref.watch(cartTotalProvider);
    final checkout = ref.watch(checkoutControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة الطلب')),
      body: state.isEmpty
          ? const Center(child: Text('السلة فارغة'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _sectionTitle('الأصناف (${state.lines.length})'),
                for (final l in state.lines) _lineBlock(context, l),
                const SizedBox(height: 8),
                _sectionTitle('الاستلام'),
                _fulfillmentRecap(state.fulfillment),
                const SizedBox(height: 12),
                const CustomerForm(),
                const SizedBox(height: 12),
                const DiscountCodeSection(),
                const SizedBox(height: 12),
                const RedeemPointsSection(),
                const SizedBox(height: 12),
                const PaymentMethodPicker(),
                const SizedBox(height: 16),
                _sectionTitle('المجموع'),
                _TotalsCard(
                  subtotal: subtotal,
                  deliveryFee: deliveryFee,
                  total: total,
                  fulfillment: state.fulfillment.type,
                  pointsToRedeem: checkout.pointsToRedeem,
                  codeDiscount: checkout.discountPreview?.discountAmount ?? 0.0,
                  codeName: checkout.discountPreview?.code,
                ),
                const SizedBox(height: 24),
              ],
            ),
      bottomNavigationBar: state.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!checkout.canSubmit && checkout.missingHint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(checkout.missingHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  FilledButton(
                    onPressed: checkout.canSubmit
                        ? () => _submit(context, ref, total)
                        : null,
                    child: checkout.stage == CheckoutStage.submitting
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_ctaLabel(checkout.paymentMethod, total)),
                  ),
                ],
              ),
            ),
    );
  }

  String _ctaLabel(PaymentMethod m, double total) {
    final t = total.toStringAsFixed(2);
    switch (m) {
      case PaymentMethod.cash:
        return 'أكد الطلب  •  $t ريال';
      case PaymentMethod.applePay:
        return 'ادفع الآن  •  $t ريال';
      case PaymentMethod.none:
        return 'متابعة  •  $t ريال';
    }
  }

  Future<void> _submit(BuildContext context, WidgetRef ref, double total) async {
    final resp = await ref.read(checkoutControllerProvider.notifier).submit();
    if (!context.mounted) return;
    if (resp == null) {
      final err = ref.read(checkoutControllerProvider).error ?? 'تعذّر إنشاء الطلب';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (resp.paymentStatus == 'confirmed') {
      // Cash path — clear cart, jump to confirmation.
      ref.read(cartControllerProvider.notifier).clear();
      ref.read(checkoutControllerProvider.notifier).reset();
      context.go('/orders/${resp.order.id}/confirmation');
    } else if (resp.paymentStatus == 'redirect') {
      // Gateway path — hand off to stub gateway screen (which handles success/fail).
      context.push('/checkout/gateway/${resp.order.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.message ?? 'فشل الدفع')),
      );
    }
  }

  // ---- helpers ----

  Widget _sectionTitle(String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(s,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Widget _lineBlock(BuildContext context, CartLine l) {
    final theme = Theme.of(context);
    // Group selections by kind so the review reads naturally.
    final byKind = <String, List<CartLineSelection>>{};
    for (final s in l.selections) {
      byKind.putIfAbsent(s.groupKind, () => []).add(s);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.nameAr,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Text('${l.quantity} × ${l.unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (byKind.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final entry in byKind.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${_kindLabel(entry.key)}: ${entry.value.map((s) => s.optionNameAr).join('، ')}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ),
            ],
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('السعر الفرعي')),
                Text('${l.linePrice.toStringAsFixed(2)} ريال',
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(String kind) => switch (kind) {
        'variant' => 'النوع',
        'size' => 'الحجم',
        'remove' => 'حذف',
        'add' => 'إضافات',
        _ => kind,
      };

  Widget _fulfillmentRecap(Fulfillment f) {
    if (f.type == FulfillmentType.delivery) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.delivery_dining_outlined),
          title: const Text('توصيل'),
          subtitle: Text(f.address ?? '—'),
        ),
      );
    }
    if (f.type == FulfillmentType.pickup) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.storefront_outlined),
          title: Text('استلام من الفرع'),
          subtitle: Text('سيتم إعداد الطلب للاستلام'),
        ),
      );
    }
    return const Card(child: ListTile(title: Text('لم يتم اختيار طريقة الاستلام')));
  }

}
