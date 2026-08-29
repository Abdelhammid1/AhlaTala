import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/checkout_controller.dart';

class PaymentMethodPicker extends ConsumerWidget {
  const PaymentMethodPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final method = ref.watch(checkoutControllerProvider.select((s) => s.paymentMethod));
    final ctrl = ref.read(checkoutControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4, bottom: 6),
          child: Text('طريقة الدفع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        Card(
          child: Column(
            children: [
              _tile(
                context: context,
                label: 'الدفع كاش عند الاستلام',
                icon: Icons.payments_outlined,
                selected: method == PaymentMethod.cash,
                onTap: () => ctrl.setPaymentMethod(PaymentMethod.cash),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _tile(
                context: context,
                label: 'Apple Pay — بوابة الدفع السعودية',
                icon: Icons.credit_card_outlined,
                selected: method == PaymentMethod.applePay,
                onTap: () => ctrl.setPaymentMethod(PaymentMethod.applePay),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: selected ? theme.colorScheme.primary : Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? theme.colorScheme.primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
