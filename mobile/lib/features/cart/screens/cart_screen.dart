import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fulfillment.dart';
import '../providers/cart_controller.dart';
import '../widgets/cart_line_tile.dart';
import '../widgets/fulfillment_picker.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartControllerProvider);
    final subtotal = state.subtotal;
    final deliveryFee = ref.watch(cartDeliveryFeeProvider);
    final total = ref.watch(cartTotalProvider);
    final canReview = ref.watch(canReviewCartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('السلة')),
      body: state.isEmpty
          ? _empty(context)
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                for (final l in state.lines)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: CartLineTile(line: l),
                  ),
                const SizedBox(height: 8),
                const FulfillmentPicker(),
                const SizedBox(height: 100),
              ],
            ),
      bottomNavigationBar: state.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _row('المجموع الفرعي', subtotal),
                  if (state.fulfillment.type == FulfillmentType.delivery)
                    _row('رسوم التوصيل', deliveryFee),
                  const Divider(height: 16),
                  _row('الإجمالي', total, emphasize: true),
                  const SizedBox(height: 10),
                  if (!canReview) _reviewHint(state),
                  FilledButton(
                    onPressed: canReview ? () => context.push('/review') : null,
                    child: const Text('مراجعة الطلب'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('السلة فارغة', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => context.go('/'),
              child: const Text('تصفح المنيو'),
            ),
          ],
        ),
      );

  Widget _row(String label, double value, {bool emphasize = false}) {
    final style = TextStyle(
      fontSize: emphasize ? 16 : 14,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('${value.toStringAsFixed(2)} ريال', style: style),
        ],
      ),
    );
  }

  Widget _reviewHint(CartState state) {
    String msg;
    if (!state.fulfillment.isChosen) {
      msg = 'اختر طريقة الاستلام (توصيل أو استلام من الفرع)';
    } else if (state.fulfillment.type == FulfillmentType.delivery) {
      msg = 'أدخل عنوان التوصيل';
    } else {
      msg = '';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontSize: 13)),
    );
  }
}
