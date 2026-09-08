import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/orders_repository.dart';
import '../../cart/providers/cart_controller.dart';
import '../../cart/providers/settings_provider.dart';
import '../widgets/status_timeline.dart';

final orderProvider = FutureProvider.autoDispose.family<OrderResp, int>((ref, id) async {
  return ref.watch(ordersRepositoryProvider).fetchOrder(id);
});

/// Order confirmation + live status tracker — rebuilt to the "متابعة الطلب"
/// Stitch mockup. Polls the order every 15s until the status is terminal,
/// re-uses the existing StatusTimeline widget so the state-machine logic
/// stays in one place.
class OrderConfirmationScreen extends ConsumerStatefulWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends ConsumerState<OrderConfirmationScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartControllerProvider.notifier).clear();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      ref.invalidate(orderProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderProvider(widget.orderId));
    async.whenData((o) {
      if (isTerminalOrderStatus(o.status) && (_pollTimer?.isActive ?? false)) {
        _pollTimer?.cancel();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorView(error: e, onRetry: () => ref.invalidate(orderProvider(widget.orderId))),
        ),
        data: (order) {
          final topPad = MediaQuery.of(context).padding.top;
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(orderProvider(widget.orderId));
                  await ref.read(orderProvider(widget.orderId).future);
                },
                child: ListView(
                  padding: EdgeInsets.only(top: topPad + 64, bottom: 120),
                  children: [
                    _StatusBanner(order: order),
                    const SizedBox(height: 12),
                    _EtaCard(order: order),
                    const SizedBox(height: 12),
                    _StatusTimelineCard(order: order),
                    const SizedBox(height: 12),
                    _OrderItemsCard(order: order),
                    const SizedBox(height: 12),
                    _TotalsCard(order: order),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _LoyaltyFeedback(order: order),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              _StickyHeader(),
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => context.go('/'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryContainer,
                      foregroundColor: AppTheme.onPrimary,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('متابعة التصفح', style: AppTheme.body(size: 15, weight: FontWeight.w700, color: AppTheme.onPrimary)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═════════════════ Sticky header ═════════════════

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
                    onTap: () => context.go('/'),
                    child: const Icon(Icons.arrow_forward, size: 20, color: AppTheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('متابعة الطلب', style: AppTheme.headline(size: 18, weight: FontWeight.w700, color: AppTheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════ Status banner (top, orange, animated dot) ═════════════════

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.order});
  final OrderResp order;

  ({String message, IconData icon}) _messageFor(String status) {
    switch (status) {
      case 'confirmed':
        return (message: 'طلبك مؤكد وسيبدأ التحضير قريباً', icon: Icons.check_circle_outline);
      case 'preparing':
        return (message: '🔥 طلبك على النار والريحة تفوح!', icon: Icons.local_fire_department);
      case 'ready_for_pickup':
        return (message: 'طلبك جاهز للاستلام من الفرع', icon: Icons.store);
      case 'on_the_way':
        return (message: '🛵 طلبك في الطريق إليك الآن', icon: Icons.two_wheeler);
      case 'delivered':
        return (message: '✅ تم التسليم — بالهناء والشفاء!', icon: Icons.done_all);
      case 'cancelled':
        return (message: '❌ تم إلغاء الطلب', icon: Icons.cancel);
      case 'failed':
        return (message: 'فشل الدفع — راسل الدعم لإكمال الطلب', icon: Icons.error);
      default:
        return (message: 'شكراً لطلبك — تم استلامه', icon: Icons.receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _messageFor(order.status);
    final terminal = isTerminalOrderStatus(order.status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: terminal
              ? (order.status == 'delivered' ? AppTheme.herbFresh : (order.status == 'cancelled' || order.status == 'failed' ? AppTheme.pomegranateRed : AppTheme.flameDeep))
              : AppTheme.flameDeep,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x33E65100), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Stack(
          children: [
            // Ambient blur accent — only for the "cooking" state
            if (order.status == 'preparing' || order.status == 'confirmed')
              Positioned(
                left: -24, bottom: -24, width: 112, height: 112,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.amberVibrant.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Row(
              children: [
                // Live pulsing dot
                if (!terminal) SizedBox(
                  width: 12, height: 12,
                  child: Stack(children: [
                    Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: AppTheme.goldLight.withValues(alpha: 0.75), shape: BoxShape.circle))),
                    const Center(child: SizedBox(
                      width: 12, height: 12,
                      child: DecoratedBox(decoration: BoxDecoration(color: AppTheme.goldLight, shape: BoxShape.circle)),
                    )),
                  ]),
                ) else Icon(info.icon, size: 18, color: AppTheme.surfaceCream),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.message,
                    style: AppTheme.body(size: 14, weight: FontWeight.w700, color: AppTheme.onPrimary, letterSpacing: 0.4),
                  ),
                ),
                // Order # pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.onTertiaryFixed.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    order.orderNumber ?? '#${order.id}',
                    style: AppTheme.priceTag(size: 14, color: AppTheme.goldLight),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════ ETA + address card ═════════════════

class _EtaCard extends StatelessWidget {
  const _EtaCard({required this.order});
  final OrderResp order;

  @override
  Widget build(BuildContext context) {
    final isDelivery = order.fulfillmentType == 'delivery';
    final terminal = isTerminalOrderStatus(order.status);
    // Rough ETA — display-only. Real ETAs would come from a delivery
    // partner integration once one is wired.
    final etaText = terminal
        ? (order.status == 'delivered' ? 'تم التسليم' : (order.status == 'cancelled' ? 'أُلغي' : 'انتهى'))
        : (isDelivery ? '25-30' : '15-20');
    final etaUnit = terminal ? '' : 'دقيقة';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.timer, size: 28, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDelivery ? 'الوقت المتوقع للوصول' : 'وقت التجهيز',
                    style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.charcoalMuted, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(etaText, style: AppTheme.headline(size: 24, weight: FontWeight.w700, color: AppTheme.primary)),
                      if (etaUnit.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(etaUnit, style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.charcoalSoft)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(isDelivery ? 'عنوان التوصيل' : 'الفرع', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.charcoalMuted, letterSpacing: 0.4)),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    isDelivery ? (order.deliveryAddress ?? '—') : 'الفرع الرئيسي',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(size: 14, weight: FontWeight.w700, color: AppTheme.onSurface),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════ Status timeline card ═════════════════

class _StatusTimelineCard extends StatelessWidget {
  const _StatusTimelineCard({required this.order});
  final OrderResp order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 3, height: 20, decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Expanded(child: Text('حالة الطلب', style: AppTheme.headline(size: 16, weight: FontWeight.w700))),
              Text('يُحدَّث تلقائياً', style: AppTheme.body(size: 10, weight: FontWeight.w600, color: AppTheme.charcoalMuted)),
            ]),
            const SizedBox(height: 8),
            StatusTimeline(
              status: order.status,
              fulfillmentType: order.fulfillmentType,
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════ Items card ═════════════════

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.order});
  final OrderResp order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 3, height: 20, decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('أصناف الطلب', style: AppTheme.headline(size: 16, weight: FontWeight.w700)),
              const Spacer(),
              Text('${order.lines.length} صنف', style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.charcoalMuted)),
            ]),
            const SizedBox(height: 12),
            for (var i = 0; i < order.lines.length; i++) ...[
              if (i > 0) const Divider(height: 20, color: AppTheme.outlineVariant),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text('${order.lines[i].quantity}×', style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.primary)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.lines[i].nameAr, style: AppTheme.body(size: 14, weight: FontWeight.w600, color: AppTheme.onSurface)),
                        if (order.lines[i].selections.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            order.lines[i].selections.map((s) => s.optionNameAr).join('، '),
                            style: AppTheme.body(size: 11, color: AppTheme.charcoalMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${order.lines[i].linePrice.toStringAsFixed(2)} ر.س', style: AppTheme.body(size: 13, weight: FontWeight.w700, color: AppTheme.onSurface)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════ Totals ═════════════════

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.order});
  final OrderResp order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          children: [
            _row('المجموع الفرعي', order.subtotal),
            if (order.fulfillmentType == 'delivery') _row('رسوم التوصيل', order.deliveryFee),
            if (order.pointsDiscount > 0) _row('خصم النقاط (${order.pointsRedeemed} نقطة)', -order.pointsDiscount, tint: AppTheme.herbFresh),
            if (order.codeDiscount > 0) _row('خصم كود${order.discountCode != null ? " (${order.discountCode})" : ""}', -order.codeDiscount, tint: AppTheme.herbFresh),
            const Divider(height: 20, color: AppTheme.outlineVariant),
            _row('الإجمالي', order.total, big: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool big = false, Color? tint}) {
    final sign = value < 0 ? '− ' : '';
    final abs = value.abs();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(label, style: AppTheme.body(size: big ? 16 : 14, weight: big ? FontWeight.w700 : FontWeight.w500, color: tint ?? (big ? AppTheme.onSurface : AppTheme.onSurfaceVariant))),
        ),
        Text(
          '$sign${abs.toStringAsFixed(2)} ر.س',
          style: big
              ? AppTheme.priceTag(size: 20, color: AppTheme.flameDeep)
              : AppTheme.body(size: 14, weight: FontWeight.w600, color: tint ?? AppTheme.onSurface),
        ),
      ]),
    );
  }
}

// ═════════════════ Loyalty feedback (preserved from original) ═════════════════

class _LoyaltyFeedback extends ConsumerWidget {
  const _LoyaltyFeedback({required this.order});
  final OrderResp order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => AppSettings.fallback(),
        );
    final chips = <Widget>[];

    if (order.pointsRedeemed > 0) {
      chips.add(_chip(
        Icons.redeem,
        'استخدمت ${order.pointsRedeemed} نقطة (خصم ${order.pointsDiscount.toStringAsFixed(2)} ر.س)',
        AppTheme.amberVibrant,
      ));
    }
    if (order.codeDiscount > 0 && order.discountCode != null) {
      chips.add(_chip(
        Icons.local_offer,
        'كود الخصم: ${order.discountCode} (خصم ${order.codeDiscount.toStringAsFixed(2)} ر.س)',
        AppTheme.primary,
      ));
    }
    if (order.pointsEarned > 0) {
      chips.add(_chip(
        Icons.stars,
        'لقد كسبت ${order.pointsEarned} نقطة!',
        AppTheme.herbFresh,
      ));
    } else if (!isTerminalOrderStatus(order.status) && settings.pointsPerRiyal > 0) {
      final estimated = (order.subtotal * settings.pointsPerRiyal).floor();
      if (estimated > 0) {
        chips.add(_chip(
          Icons.stars_outlined,
          'ستحصل على ~$estimated نقطة عند التسليم',
          AppTheme.charcoalMuted,
        ));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Column(children: [for (final c in chips) Padding(padding: const EdgeInsets.only(bottom: 8), child: c)]);
  }

  Widget _chip(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTheme.body(size: 13, weight: FontWeight.w700, color: color))),
        ]),
      );
}
