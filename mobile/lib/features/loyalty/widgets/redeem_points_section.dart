import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/providers/cart_controller.dart';
import '../../cart/providers/settings_provider.dart';
import '../../checkout/controllers/checkout_controller.dart';
import '../providers/loyalty_providers.dart';

/// Appears on the review screen when the customer's phone is known AND
/// they have enough points to hit `min_redeem_points`. Shows a stepper
/// (in `min` increments) up to whichever is smaller: their balance or the
/// point-count equivalent of the current subtotal.
class RedeemPointsSection extends ConsumerWidget {
  const RedeemPointsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(checkoutControllerProvider.select((s) => s.customerPhone));
    if (phone.trim().length < 4) return const SizedBox.shrink();

    final balanceAsync = ref.watch(customerBalanceProvider(phone));
    final subtotal = ref.watch(cartControllerProvider.select((s) => s.subtotal));
    final settings = ref.watch(settingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => AppSettings.fallback(),
        );

    return balanceAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (bal) {
        if (bal == null || bal.pointsBalance < settings.minRedeemPoints) {
          return const SizedBox.shrink();
        }
        return _RedeemCard(
          balance: bal.pointsBalance,
          subtotal: subtotal,
          settings: settings,
        );
      },
    );
  }
}

class _RedeemCard extends ConsumerStatefulWidget {
  const _RedeemCard({
    required this.balance,
    required this.subtotal,
    required this.settings,
  });
  final int balance;
  final double subtotal;
  final AppSettings settings;

  @override
  ConsumerState<_RedeemCard> createState() => _RedeemCardState();
}

class _RedeemCardState extends ConsumerState<_RedeemCard> {
  int _points = 0;

  int get _step => math.max(widget.settings.minRedeemPoints, 1);

  int get _maxPoints {
    final byBalance = widget.balance;
    final byCart = widget.settings.riyalPerPoint <= 0
        ? 0
        : (widget.subtotal / widget.settings.riyalPerPoint).floor();
    final cap = math.min(byBalance, byCart);
    // Round DOWN to the nearest _step so we can't offer 137 pts when step is 100.
    return (cap ~/ _step) * _step;
  }

  double get _discount => _points * widget.settings.riyalPerPoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = _maxPoints;
    if (max < _step) return const SizedBox.shrink();

    // Sync into CheckoutController on every rebuild so submit picks it up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkoutControllerProvider.notifier).setPointsToRedeem(_points);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4, bottom: 6),
          child: Text('استخدام نقاط الولاء', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.stars_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('رصيدك: ${widget.balance} نقطة',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_discount > 0)
                    Text('خصم ${_discount.toStringAsFixed(2)} ريال',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _btn(Icons.remove, () => setState(() => _points = math.max(0, _points - _step))),
                  const SizedBox(width: 12),
                  Text('$_points نقطة',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  _btn(Icons.add, () => setState(() => _points = math.min(max, _points + _step))),
                  const Spacer(),
                  TextButton(
                    onPressed: _points == max ? null : () => setState(() => _points = max),
                    child: const Text('الحد الأقصى'),
                  ),
                ]),
                Text(
                  'كل ${(1 / widget.settings.riyalPerPoint).toStringAsFixed(0)} نقاط = ريال. الحد الأدنى للاستبدال: $_step نقطة.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon),
          onPressed: onTap,
        ),
      );
}
