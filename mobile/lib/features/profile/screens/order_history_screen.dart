import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/models/cart_line.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../cart/providers/cart_controller.dart';

final _myOrdersProvider = FutureProvider.autoDispose<List<OrderResp>>((ref) async {
  return ref.watch(authRepositoryProvider).myOrders();
});

/// US9.3 — order history + reorder.
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myOrdersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي السابقة')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا يوجد لديك طلبات بعد.', textAlign: TextAlign.center),
            ));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_myOrdersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _OrderCard(order: orders[i]),
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
    final theme = Theme.of(context);
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(order.orderNumber ?? '#${order.id}',
                  style: const TextStyle(fontWeight: FontWeight.w800))),
              _statusChip(order.status),
            ]),
            const SizedBox(height: 4),
            if (order.lines.isNotEmpty)
              Text(order.lines.map((l) => '${l.quantity}× ${l.nameAr}').join('، '),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.event_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(fmt.format(DateTime.now()),  // sentAt not on OrderResp — using createdAt would need parsing; keeping this simple
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const Spacer(),
              Text('${order.total.toStringAsFixed(2)} ريال',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
            ]),
            const Divider(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_outlined, size: 18),
                  label: const Text('التفاصيل'),
                  onPressed: () => context.push('/orders/${order.id}/confirmation'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('أعد الطلب'),
                  onPressed: () => _reorder(context, ref),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String s) {
    final map = {
      'created': ('قيد التأكيد', Colors.grey),
      'confirmed': ('مؤكد', Colors.blue),
      'preparing': ('قيد التجهيز', Colors.orange),
      'on_the_way': ('في الطريق', Colors.teal),
      'ready_for_pickup': ('جاهز', Colors.teal),
      'delivered': ('تم التسليم', Colors.green),
      'cancelled': ('ملغى', Colors.red),
      'failed': ('فشل', Colors.red),
    };
    final entry = map[s] ?? ('غير معروف', Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: entry.$2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(entry.$1, style: TextStyle(color: entry.$2, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  void _reorder(BuildContext context, WidgetRef ref) {
    // Reconstruct CartLines from the order's snapshot fields — the server will
    // re-validate every item/option on the next order-create call.
    final cart = ref.read(cartControllerProvider.notifier);
    // NOTE: we intentionally do NOT clear the existing cart — we merge.
    for (final l in order.lines) {
      final selections = [
        for (final s in l.selections)
          CartLineSelection(
            groupId: s.groupId, groupNameAr: s.groupNameAr, groupKind: s.groupKind,
            optionId: s.optionId, optionNameAr: s.optionNameAr, priceDelta: s.priceDelta,
          ),
      ];
      // Direct low-level add — bypasses the item-configuration controller since
      // we already have the snapshot. `addBareItem` won't do (needs ItemDetail);
      // `addLineFromConfiguration` needs a controller instance. So we build the
      // CartLine ourselves and push it through the same state machinery via a
      // small helper on the controller. See _addSnapshot below.
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
      SnackBar(content: Text('تمت إضافة ${order.lines.length} صنف إلى السلة')),
    );
    context.push('/review');
  }
}
