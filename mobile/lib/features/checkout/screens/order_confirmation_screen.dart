import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/order.dart';
import '../../../data/repositories/orders_repository.dart';
import '../../cart/providers/cart_controller.dart';
import '../../cart/providers/settings_provider.dart';
import '../widgets/status_timeline.dart';

final orderProvider = FutureProvider.autoDispose.family<OrderResp, int>((ref, id) async {
  return ref.watch(ordersRepositoryProvider).fetchOrder(id);
});

/// US3.3 — confirmation view + E4 US4.2 live-ish status updates:
/// polls the order every 15s and offers pull-to-refresh so the customer sees
/// admin status changes without leaving the screen. Timer cancels once the
/// status is terminal (delivered / cancelled / failed).
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
    // Safety net: cart should already be empty (cash path clears; gateway path clears too),
    // but re-arm here in case someone lands via URL / restart.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartControllerProvider.notifier).clear();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      // Cheap: invalidate refetches only for consumers on this screen.
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

    // If we know we're terminal, kill the timer so we stop hitting the network.
    async.whenData((o) {
      if (isTerminalOrderStatus(o.status) && (_pollTimer?.isActive ?? false)) {
        _pollTimer?.cancel();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد الطلب'),
        automaticallyImplyLeading: false,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (order) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(orderProvider(widget.orderId));
            await ref.read(orderProvider(widget.orderId).future);
          },
          child: _content(context, order),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('متابعة التصفح'),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, OrderResp order) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 4),
        Center(
          child: Container(
            width: 96, height: 96,
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.check_circle, size: 72, color: Colors.green.shade600),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text('شكراً لطلبك',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            order.paymentMethod == 'cash'
                ? 'تم استلام طلبك وسيتم تجهيزه قريباً'
                : 'تم استلام الدفع وسيتم تجهيز طلبك',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        const SizedBox(height: 20),

        // ---- STATUS TIMELINE (E4 US4.2) ----
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('حالة الطلب',
                        style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                    const Spacer(),
                    Text('يُحدَّث تلقائياً',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
                StatusTimeline(
                  status: order.status,
                  fulfillmentType: order.fulfillmentType,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text('رقم الطلب: ${order.orderNumber ?? '#${order.id}'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('الحالة: ${orderStatusAr(order.status)}'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الاستلام', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                const SizedBox(height: 6),
                if (order.fulfillmentType == 'delivery') ...[
                  const Text('توصيل'),
                  const SizedBox(height: 2),
                  Text(order.deliveryAddress ?? '—',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                ] else
                  const Text('استلام من الفرع'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الأصناف', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                const SizedBox(height: 4),
                for (final l in order.lines) ...[
                  const Divider(),
                  Row(children: [
                    Expanded(
                      child: Text('${l.quantity} × ${l.nameAr}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text('${l.linePrice.toStringAsFixed(2)} ريال'),
                  ]),
                  if (l.selections.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l.selections.map((s) => s.optionNameAr).join('، '),
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _row('المجموع الفرعي', order.subtotal),
                if (order.fulfillmentType == 'delivery')
                  _row('رسوم التوصيل', order.deliveryFee),
                if (order.pointsDiscount > 0)
                  _row('خصم النقاط', -order.pointsDiscount, tint: Colors.green.shade700),
                if (order.codeDiscount > 0)
                  _row('خصم كود${order.discountCode != null ? " (${order.discountCode})" : ""}',
                      -order.codeDiscount, tint: Colors.green.shade700),
                const Divider(),
                _row('الإجمالي', order.total, emphasize: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _LoyaltyFeedback(order: order),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _row(String label, double value, {bool emphasize = false, Color? tint}) {
    final style = TextStyle(
      fontSize: emphasize ? 16 : 14,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
      color: tint,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text('${value.toStringAsFixed(2)} ريال', style: style),
      ]),
    );
  }
}

/// Points-earned / points-redeemed feedback. Uses `points_earned` from the
/// server once delivered; before then, computes a prospective estimate from
/// `subtotal * points_per_riyal` so the customer knows what they'll get.
class _LoyaltyFeedback extends ConsumerWidget {
  const _LoyaltyFeedback({required this.order});
  final OrderResp order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => AppSettings.fallback(),
        );
    final rows = <Widget>[];

    if (order.pointsRedeemed > 0) {
      rows.add(_chip(
        Icons.redeem_outlined,
        'استخدمت ${order.pointsRedeemed} نقطة (خصم ${order.pointsDiscount.toStringAsFixed(2)} ريال)',
        Colors.orange.shade700,
      ));
    }
    if (order.codeDiscount > 0 && order.discountCode != null) {
      rows.add(_chip(
        Icons.local_offer_outlined,
        'كود الخصم: ${order.discountCode} (خصم ${order.codeDiscount.toStringAsFixed(2)} ريال)',
        Colors.blue.shade700,
      ));
    }

    if (order.pointsEarned > 0) {
      rows.add(_chip(
        Icons.stars_rounded,
        'لقد كسبت ${order.pointsEarned} نقطة!',
        Colors.green.shade700,
      ));
    } else if (!isTerminalOrderStatus(order.status) && settings.pointsPerRiyal > 0) {
      final estimated = (order.subtotal * settings.pointsPerRiyal).floor();
      if (estimated > 0) {
        rows.add(_chip(
          Icons.stars_outlined,
          'ستحصل على ~$estimated نقطة عند التسليم',
          Colors.grey.shade700,
        ));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(children: [for (final r in rows) Padding(padding: const EdgeInsets.only(top: 6), child: r)]);
  }

  Widget _chip(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
        ]),
      );
}
