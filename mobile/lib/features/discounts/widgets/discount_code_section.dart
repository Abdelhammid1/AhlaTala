import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/providers/cart_controller.dart';
import '../../cart/providers/settings_provider.dart';
import '../../checkout/controllers/checkout_controller.dart';

/// "كود الخصم" text field + apply button on the review screen (E6 US6.2).
///
/// Success replaces the field with a green chip showing the discount + an
/// "إزالة" X. Failure shows a red Arabic error below the field.
class DiscountCodeSection extends ConsumerStatefulWidget {
  const DiscountCodeSection({super.key});

  @override
  ConsumerState<DiscountCodeSection> createState() => _DiscountCodeSectionState();
}

class _DiscountCodeSectionState extends ConsumerState<DiscountCodeSection> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(checkoutControllerProvider);
    final subtotal = ref.watch(cartControllerProvider.select((s) => s.subtotal));
    final settings = ref.watch(settingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => AppSettings.fallback(),
        );
    final pointsDiscount = state.pointsToRedeem * settings.riyalPerPoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4, bottom: 6),
          child: Text('كود الخصم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: state.discountPreview != null
                ? _applied(context, state.discountPreview!.code, state.discountPreview!.discountAmount, theme)
                : _entry(context, state, subtotal, pointsDiscount, theme),
          ),
        ),
      ],
    );
  }

  Widget _entry(
    BuildContext context,
    CheckoutState state,
    double subtotal,
    double pointsDiscount,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.local_offer_outlined),
                hintText: 'أدخل كود الخصم',
                errorText: state.discountError,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _busy ? null : () => _apply(subtotal, pointsDiscount),
            child: _busy
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('تطبيق'),
          ),
        ]),
      ],
    );
  }

  Widget _applied(BuildContext context, String code, double amount, ThemeData theme) {
    return Row(children: [
      Icon(Icons.check_circle, color: Colors.green.shade700),
      const SizedBox(width: 8),
      Expanded(
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'الكود '),
            TextSpan(text: code, style: const TextStyle(fontWeight: FontWeight.w800)),
            const TextSpan(text: ' — '),
            TextSpan(
              text: 'خصم ${amount.toStringAsFixed(2)} ريال',
              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w800),
            ),
          ]),
        ),
      ),
      IconButton(
        tooltip: 'إزالة',
        icon: const Icon(Icons.close),
        onPressed: () {
          _codeCtrl.clear();
          ref.read(checkoutControllerProvider.notifier).clearDiscountCode();
        },
      ),
    ]);
  }

  Future<void> _apply(double subtotal, double pointsDiscount) async {
    setState(() => _busy = true);
    await ref
        .read(checkoutControllerProvider.notifier)
        .applyDiscountCode(_codeCtrl.text, subtotal: subtotal, pointsDiscount: pointsDiscount);
    if (mounted) setState(() => _busy = false);
  }
}
