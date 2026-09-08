import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/stitch_bottom_nav.dart';
import '../../../data/models/cart_line.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../cart/providers/cart_controller.dart';

final myOrdersProvider = FutureProvider.autoDispose<List<OrderResp>>((ref) async {
  return ref.watch(authRepositoryProvider).myOrders();
});

/// "طلباتي" — order history matching the Stitch design.
class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  _StatusFilter _filter = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    if (session == null) return const _LoggedOutState();
    final async = ref.watch(myOrdersProvider);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _Header(),
                _FilterChips(
                  filter: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                  orders: async.valueOrNull ?? [],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: async.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: ErrorView(error: e, onRetry: () => ref.invalidate(myOrdersProvider)),
                    ),
                    data: (orders) {
                      final filtered = _apply(orders, _filter);
                      if (orders.isEmpty) return const _EmptyState();
                      if (filtered.isEmpty) return _NoMatch(filter: _filter);
                      return RefreshIndicator(
                        onRefresh: () async => ref.invalidate(myOrdersProvider),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          children: [
                            for (final o in filtered)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _OrderCard(order: o),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: StitchBottomNav(active: StitchNavTab.orders)),
        ],
      ),
    );
  }

  static List<OrderResp> _apply(List<OrderResp> orders, _StatusFilter f) {
    switch (f) {
      case _StatusFilter.all: return orders;
      case _StatusFilter.inProgress:
        return orders.where((o) => !isTerminalOrderStatus(o.status)).toList();
      case _StatusFilter.delivered:
        return orders.where((o) => o.status == 'delivered').toList();
      case _StatusFilter.cancelled:
        return orders.where((o) => o.status == 'cancelled' || o.status == 'failed').toList();
    }
  }
}

enum _StatusFilter { all, inProgress, delivered, cancelled }

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44, height: 44,
            child: Material(
              color: AppTheme.surfaceContainer,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
                child: const Icon(Icons.arrow_forward, size: 20, color: AppTheme.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('طلباتي', style: AppTheme.headline(size: 22, weight: FontWeight.w700, color: AppTheme.onSurface)),
              Text('راجع طلباتك السابقة أو أعد الطلب بضغطة', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.filter, required this.onChanged, required this.orders});
  final _StatusFilter filter;
  final ValueChanged<_StatusFilter> onChanged;
  final List<OrderResp> orders;

  int _count(_StatusFilter f) => _OrderHistoryScreenState._apply(orders, f).length;

  @override
  Widget build(BuildContext context) {
    final chips = <(_StatusFilter, String)>[
      (_StatusFilter.all, 'الكل'),
      (_StatusFilter.inProgress, 'قيد التنفيذ'),
      (_StatusFilter.delivered, 'مكتمل'),
      (_StatusFilter.cancelled, 'ملغى'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (f, label) = chips[i];
          final selected = f == filter;
          final n = _count(f);
          return InkWell(
            onTap: () => onChanged(f),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.charcoalSoft : AppTheme.surfaceCreamSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: AppTheme.body(size: 13, weight: FontWeight.w700, color: selected ? AppTheme.surfaceBright : AppTheme.charcoalSoft)),
                if (n > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0x33FDFAF6) : AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$n', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: selected ? AppTheme.surfaceBright : AppTheme.onSurface)),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final OrderResp order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminal = isTerminalOrderStatus(order.status);
    final (statusLabel, statusColor) = _statusChip(order.status);
    return InkWell(
      onTap: () => context.push('/orders/${order.id}/confirmation'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long, size: 22, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(order.orderNumber ?? '#${order.id}', style: AppTheme.headline(size: 16, weight: FontWeight.w700, color: AppTheme.onSurface)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(statusLabel, style: AppTheme.body(size: 10, weight: FontWeight.w700, color: statusColor)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text('${order.lines.length} صنف · ${order.fulfillmentType == "delivery" ? "توصيل" : "استلام"}',
                        style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${order.total.toStringAsFixed(2)} ر.س', style: AppTheme.priceTag(size: 16, color: AppTheme.flameDeep)),
                ],
              ),
            ]),
            if (order.lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                order.lines.map((l) => '${l.quantity}× ${l.nameAr}').join('  ·  '),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/orders/${order.id}/confirmation'),
                  icon: const Icon(Icons.receipt_outlined, size: 18, color: AppTheme.charcoalSoft),
                  label: Text('التفاصيل', style: AppTheme.body(size: 13, weight: FontWeight.w700, color: AppTheme.charcoalSoft)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppTheme.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (terminal && order.status == 'delivered')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/orders/${order.id}/rate'),
                    icon: const Icon(Icons.star_outline, size: 18, color: AppTheme.amberVibrant),
                    label: Text('قيّم', style: AppTheme.body(size: 13, weight: FontWeight.w700, color: AppTheme.amberVibrant)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: AppTheme.amberVibrant.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              if (terminal && order.status == 'delivered') const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _reorder(context, ref),
                  icon: const Icon(Icons.replay, size: 18),
                  label: Text('أعد الطلب', style: AppTheme.body(size: 13, weight: FontWeight.w700, color: AppTheme.onPrimary)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    foregroundColor: AppTheme.onPrimary,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  (String, Color) _statusChip(String s) {
    switch (s) {
      case 'created':          return ('قيد التأكيد', AppTheme.charcoalMuted);
      case 'confirmed':        return ('مؤكد', const Color(0xFF0D9488));
      case 'preparing':        return ('قيد التجهيز', AppTheme.primaryContainer);
      case 'on_the_way':       return ('في الطريق', const Color(0xFF6366F1));
      case 'ready_for_pickup': return ('جاهز', const Color(0xFF3B82F6));
      case 'delivered':        return ('تم التسليم', AppTheme.herbFresh);
      case 'cancelled':        return ('ملغى', AppTheme.pomegranateRed);
      case 'failed':           return ('فشل الدفع', AppTheme.pomegranateRed);
      default:                 return (s, AppTheme.charcoalMuted);
    }
  }

  void _reorder(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartControllerProvider.notifier);
    for (final l in order.lines) {
      final selections = [
        for (final s in l.selections)
          CartLineSelection(
            groupId: s.groupId, groupNameAr: s.groupNameAr, groupKind: s.groupKind,
            optionId: s.optionId, optionNameAr: s.optionNameAr, priceDelta: s.priceDelta,
          ),
      ];
      cart.addSnapshot(
        itemId: l.itemId ?? 0,
        nameAr: l.nameAr,
        imageUrl: l.imageUrl,
        basePrice: l.basePrice,
        quantity: l.quantity,
        selections: selections,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة ${order.lines.length} صنف إلى السلة'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.push('/review');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 80, color: AppTheme.primaryContainer),
            const SizedBox(height: 12),
            Text('لا يوجد لديك طلبات بعد', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('كل طلب جديد يظهر هنا مع خيار "أعد الطلب" بضغطة واحدة.',
                textAlign: TextAlign.center, style: AppTheme.body(size: 13, color: AppTheme.charcoalMuted)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('تصفح القائمة'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryContainer, foregroundColor: AppTheme.onPrimary, minimumSize: const Size(220, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.filter});
  final _StatusFilter filter;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_off, size: 64, color: AppTheme.charcoalMuted),
            const SizedBox(height: 12),
            Text('لا طلبات بهذا الفلتر', style: AppTheme.body(size: 15, weight: FontWeight.w700, color: AppTheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _LoggedOutState extends StatelessWidget {
  const _LoggedOutState();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 72, color: AppTheme.primaryContainer),
                const SizedBox(height: 12),
                Text('سجّل الدخول لرؤية طلباتك', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('طلباتك السابقة محفوظة في حسابك — سجّل دخولك لعرضها.',
                    textAlign: TextAlign.center, style: AppTheme.body(size: 13, color: AppTheme.charcoalMuted)),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.push('/login'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryContainer, foregroundColor: AppTheme.onPrimary, minimumSize: const Size(220, 48)),
                  child: const Text('تسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
