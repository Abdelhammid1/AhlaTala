import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/orders_repository.dart';
import '../../cart/providers/cart_controller.dart';

/// Mock "بوابة الدفع السعودية" landing (US3.2 flow shape).
/// Real gateway: the SDK would call this same POST /confirm on success and
/// /fail on cancel. Once Moyasar/HyperPay/Tap is picked, replace this screen
/// with the SDK's checkout flow.
class GatewayStubScreen extends ConsumerStatefulWidget {
  const GatewayStubScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<GatewayStubScreen> createState() => _GatewayStubScreenState();
}

class _GatewayStubScreenState extends ConsumerState<GatewayStubScreen> {
  bool _busy = false;

  Future<void> _simulateSuccess() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(ordersRepositoryProvider)
          .confirmOrder(widget.orderId, reference: 'stub-${DateTime.now().millisecondsSinceEpoch}');
      // Success: clear cart, go to confirmation
      ref.read(cartControllerProvider.notifier).clear();
      if (!mounted) return;
      context.go('/orders/${widget.orderId}/confirmation');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تأكيد الدفع')),
      );
    }
  }

  Future<void> _simulateFail() async {
    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).failOrder(widget.orderId);
    } catch (_) {/* fall through — user sees the snackbar on review either way */}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('فشلت عملية الدفع — حاول مرة أخرى')),
    );
    // Back to review, cart preserved
    context.go('/review');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بوابة الدفع')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(
                child: Icon(Icons.credit_card, size: 72, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Text(
                'بوابة الدفع السعودية',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'هذه شاشة محاكاة — سيتم استبدالها بـ Moyasar / HyperPay / Tap لاحقاً.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _busy ? null : _simulateSuccess,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('محاكاة نجاح الدفع'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy ? null : _simulateFail,
                child: const Text('محاكاة فشل الدفع'),
              ),
              const Spacer(),
              Text(
                'رقم الطلب: #${widget.orderId}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
