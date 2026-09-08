import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/food_image.dart';
import '../../checkout/controllers/checkout_controller.dart';
import '../../checkout/widgets/customer_form.dart';
import '../../checkout/widgets/payment_method_picker.dart';
import '../../discounts/widgets/discount_code_section.dart';
import '../../loyalty/widgets/redeem_points_section.dart';
import '../models/fulfillment.dart';
import '../providers/cart_controller.dart';
import '../providers/settings_provider.dart';

/// Threshold above which delivery is "free" for the progress-bar UI at
/// the top of the cart. This is a display-only hint — the real delivery
/// fee logic still runs on the server via the settings endpoint. When
/// the backend grows a real free-delivery threshold field this constant
/// gets deleted and the value moves into AppSettings.
const double _kFreeDeliveryThreshold = 100.0;

/// Cart + checkout — rebuilt to the "cart and pay.html" Stitch mockup.
class OrderReviewScreen extends ConsumerWidget {
  const OrderReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartControllerProvider);
    final subtotal = state.subtotal;
    final deliveryFee = ref.watch(cartDeliveryFeeProvider);
    final total = ref.watch(cartTotalProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final topPad = MediaQuery.of(context).padding.top;

    if (state.isEmpty) return const _EmptyCart();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(top: topPad + 64, bottom: 200),
            children: [
              _FreeDeliveryBanner(subtotal: subtotal, fulfillment: state.fulfillment),
              const SizedBox(height: 16),
              _ItemsSection(),
              const SizedBox(height: 8),
              _FulfillmentRecap(fulfillment: state.fulfillment),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: CustomerForm(),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: DiscountCodeSection(),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: RedeemPointsSection(),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: PaymentMethodPicker(),
              ),
              const SizedBox(height: 16),
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
          _StickyHeader(),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _BottomCta(
              total: total - (checkout.discountPreview?.discountAmount ?? 0.0) -
                  (checkout.pointsToRedeem * _pointsToRiyal(ref)),
              canSubmit: checkout.canSubmit,
              missingHint: checkout.missingHint,
              submitting: checkout.stage == CheckoutStage.submitting,
              paymentMethod: checkout.paymentMethod,
              onSubmit: () => _submit(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  double _pointsToRiyal(WidgetRef ref) {
    return ref.watch(settingsProvider).maybeWhen(
          data: (s) => s.riyalPerPoint,
          orElse: () => AppSettings.fallback().riyalPerPoint,
        );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final resp = await ref.read(checkoutControllerProvider.notifier).submit();
    if (!context.mounted) return;
    if (resp == null) {
      final err = ref.read(checkoutControllerProvider).error ?? 'تعذّر إنشاء الطلب';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (resp.paymentStatus == 'confirmed') {
      ref.read(cartControllerProvider.notifier).clear();
      ref.read(checkoutControllerProvider.notifier).reset();
      context.go('/orders/${resp.order.id}/confirmation');
    } else if (resp.paymentStatus == 'redirect') {
      context.push('/checkout/gateway/${resp.order.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.message ?? 'فشل الدفع')),
      );
    }
  }
}

// ═════════════════ Empty cart state ═════════════════

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('السلة'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 64, color: AppTheme.primaryContainer),
            const SizedBox(height: 12),
            Text('السلة فارغة', style: AppTheme.headline(size: 20, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('أضف صنفاً من القائمة لتبدأ الطلب', style: AppTheme.body(size: 14, color: AppTheme.charcoalMuted)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/'),
              style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
              child: const Text('تصفح القائمة'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════ Sticky glass header ═════════════════

class _StickyHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        color: const Color(0xD9FFF8F6),
        padding: EdgeInsets.only(top: top),
        height: top + 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 40, height: 40,
                child: Material(
                  color: AppTheme.surfaceContainer,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                    child: const Icon(Icons.arrow_forward, size: 20, color: AppTheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('مراجعة الطلب', style: AppTheme.headline(size: 18, weight: FontWeight.w700, color: AppTheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════ Free delivery threshold banner ═════════════════

class _FreeDeliveryBanner extends StatelessWidget {
  const _FreeDeliveryBanner({required this.subtotal, required this.fulfillment});
  final double subtotal;
  final Fulfillment fulfillment;

  @override
  Widget build(BuildContext context) {
    // Only show for delivery orders — pickup has no fee to save.
    if (fulfillment.type != FulfillmentType.delivery) return const SizedBox.shrink();
    final remaining = (_kFreeDeliveryThreshold - subtotal).clamp(0.0, _kFreeDeliveryThreshold);
    final progress = (subtotal / _kFreeDeliveryThreshold).clamp(0.0, 1.0);
    final earned = remaining <= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(999)),
                child: const Icon(Icons.two_wheeler, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  earned
                      ? 'تهانينا! التوصيل مجاني على هذا الطلب 🎉'
                      : 'أنت على بعد ${remaining.toStringAsFixed(0)} ر.س من التوصيل المجاني 🛵',
                  style: AppTheme.headline(size: 15, weight: FontWeight.w600, color: AppTheme.onSurface),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(progress * 100).toStringAsFixed(0)}٪',
                style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.primary),
              ),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppTheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryContainer),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              earned ? 'استمتع بتوصيل مجاني — لا تنسَ نقاط الولاء!' : 'أضف مشروباً أو مقبلات لتوفير رسوم التوصيل كاملة',
              style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════ Items section (with qty steppers) ═════════════════

class _ItemsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('أصناف الطلب (${state.lines.length})', style: AppTheme.headline(size: 18, weight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () => ref.read(cartControllerProvider.notifier).clear(),
                icon: const Icon(Icons.delete_sweep, size: 16, color: AppTheme.pomegranateRed),
                label: Text('مسح السلة', style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.pomegranateRed)),
                style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...state.lines.map((l) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _CartLineTile(lineId: l.id),
            )),
      ],
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.lineId});
  final String lineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartControllerProvider);
    final line = state.lines.firstWhere((l) => l.id == lineId, orElse: () => state.lines.first);
    final controller = ref.read(cartControllerProvider.notifier);
    // Group selections by kind for a compact subtitle row.
    final chips = line.selections.map((s) {
      final prefix = switch (s.groupKind) { 'remove' => '−', 'add' => '+', _ => '' };
      return prefix.isEmpty ? s.optionNameAr : '$prefix ${s.optionNameAr}';
    }).join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80, height: 80,
              child: FoodImage(url: line.imageUrl, icon: Icons.local_fire_department, iconSize: 32),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        line.nameAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.headline(size: 16, weight: FontWeight.w600, color: AppTheme.onSurface),
                      ),
                    ),
                    SizedBox(
                      width: 32, height: 32,
                      child: IconButton(
                        onPressed: () => controller.removeLine(line.id),
                        icon: const Icon(Icons.close, size: 18, color: AppTheme.charcoalMuted),
                        padding: EdgeInsets.zero,
                        splashRadius: 18,
                      ),
                    ),
                  ],
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(chips, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(line.linePrice.toStringAsFixed(line.linePrice == line.linePrice.roundToDouble() ? 0 : 2),
                            style: AppTheme.priceTag(color: AppTheme.onSurface)),
                        const SizedBox(width: 4),
                        Text('ر.س', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _stepBtn(icon: Icons.remove, onTap: () => controller.updateQuantity(line.id, line.quantity - 1), lightBg: true),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('${line.quantity}', style: AppTheme.headline(size: 16, weight: FontWeight.w700, color: AppTheme.onSurface)),
                          ),
                          _stepBtn(icon: Icons.add, onTap: () => controller.updateQuantity(line.id, line.quantity + 1), lightBg: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn({required IconData icon, required VoidCallback onTap, required bool lightBg}) {
    return Material(
      color: lightBg ? AppTheme.surfaceContainerLowest : AppTheme.primaryContainer,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 24, height: 24,
          child: Icon(icon, size: 16, color: lightBg ? AppTheme.onSurface : AppTheme.onPrimary),
        ),
      ),
    );
  }
}

// ═════════════════ Fulfillment recap card ═════════════════

class _FulfillmentRecap extends StatelessWidget {
  const _FulfillmentRecap({required this.fulfillment});
  final Fulfillment fulfillment;
  @override
  Widget build(BuildContext context) {
    final isDelivery = fulfillment.type == FulfillmentType.delivery;
    final isNone = fulfillment.type == FulfillmentType.none;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isNone ? AppTheme.errorContainer : AppTheme.primaryFixed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isNone ? Icons.error_outline : (isDelivery ? Icons.two_wheeler : Icons.storefront),
                color: isNone ? AppTheme.error : AppTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNone ? 'اختر طريقة الاستلام' : (isDelivery ? 'توصيل' : 'استلام من الفرع'),
                    style: AppTheme.headline(size: 14, weight: FontWeight.w700, color: AppTheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDelivery
                        ? (fulfillment.address ?? 'يُرجى إدخال العنوان في نموذج البيانات أدناه')
                        : (isNone ? 'مطلوب — لا يمكن تأكيد الطلب دون اختيارها' : 'الطلب سيكون جاهزاً للاستلام من فرعنا'),
                    style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════ Totals card ═════════════════

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(children: [
              Container(
                width: 3, height: 20, decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text('ملخص الفاتورة', style: AppTheme.headline(size: 16, weight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            _row('المجموع الفرعي', subtotal),
            if (fulfillment == FulfillmentType.delivery) _row('رسوم التوصيل', deliveryFee),
            if (pointsDiscount > 0) _row('خصم النقاط ($pointsToRedeem نقطة)', -pointsDiscount, tint: AppTheme.herbFresh),
            if (codeDiscount > 0) _row('خصم كود${codeName != null ? " ($codeName)" : ""}', -codeDiscount, tint: AppTheme.herbFresh),
            const Divider(height: 20, color: AppTheme.outlineVariant),
            _row('الإجمالي المستحق', adjustedTotal, big: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool big = false, Color? tint}) {
    final sign = value < 0 ? '− ' : '';
    final abs = value.abs();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.body(
                size: big ? 16 : 14,
                weight: big ? FontWeight.w700 : FontWeight.w500,
                color: tint ?? (big ? AppTheme.onSurface : AppTheme.onSurfaceVariant),
              ),
            ),
          ),
          Text(
            '$sign${abs.toStringAsFixed(2)} ر.س',
            style: big
                ? AppTheme.priceTag(size: 20, color: AppTheme.flameDeep)
                : AppTheme.body(size: 14, weight: FontWeight.w600, color: tint ?? AppTheme.onSurface),
          ),
        ],
      ),
    );
  }
}

// ═════════════════ Bottom CTA ═════════════════

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.total,
    required this.canSubmit,
    required this.missingHint,
    required this.submitting,
    required this.paymentMethod,
    required this.onSubmit,
  });
  final double total;
  final bool canSubmit;
  final String missingHint;
  final bool submitting;
  final PaymentMethod paymentMethod;
  final VoidCallback onSubmit;

  String get _ctaLabel {
    final t = total.toStringAsFixed(2);
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return 'أكد الطلب  •  $t ر.س';
      case PaymentMethod.applePay:
        return 'ادفع الآن  •  $t ر.س';
      case PaymentMethod.none:
        return 'متابعة  •  $t ر.س';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        boxShadow: [BoxShadow(color: Color(0x1A1F1B19), blurRadius: 20, offset: Offset(0, -6))],
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!canSubmit && missingHint.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(missingHint, textAlign: TextAlign.center, style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.pomegranateRed)),
                ),
              FilledButton(
                onPressed: (canSubmit && !submitting) ? onSubmit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  disabledBackgroundColor: AppTheme.surfaceContainer,
                  foregroundColor: AppTheme.onPrimary,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: const Color(0x59E87722),
                ),
                child: submitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary),
                      )
                    : Text(_ctaLabel, style: AppTheme.body(size: 15, weight: FontWeight.w700, color: canSubmit ? AppTheme.onPrimary : AppTheme.charcoalMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
