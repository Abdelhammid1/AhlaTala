import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../../features/cart/providers/cart_controller.dart';

/// The dark floating "sales bar" from the Stitch home design that hovers
/// above the bottom nav when the cart isn't empty. Wired to the real
/// cart controller — quantity + subtotal come straight from state, tapping
/// the CTA pushes /review.
///
/// Positioned by the parent (usually a Stack in the home screen with
/// `bottom: 80` so it sits above the 64px nav + safe-area).
class FloatingCartBar extends ConsumerWidget {
  const FloatingCartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartControllerProvider);
    final subtotal = state.subtotal;
    final itemCount = state.lines.fold<int>(0, (n, l) => n + l.quantity);
    if (itemCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.charcoalSoft,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x401F1B19), blurRadius: 28, offset: Offset(0, 12)),
          ],
        ),
        child: Row(
          children: [
            // Bag icon with count badge
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.flameDeep,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_bag, size: 22, color: Colors.white),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCream,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
                      ),
                      child: Text(
                        '$itemCount',
                        style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.charcoalSoft),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Item count + total
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$itemCount أصناف في السلة',
                    style: AppTheme.body(size: 12, weight: FontWeight.w600, color: const Color(0xCCFDFAF6)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        subtotal.toStringAsFixed(subtotal == subtotal.roundToDouble() ? 0 : 2),
                        style: AppTheme.priceTag(color: AppTheme.surfaceBright),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ر.س',
                        style: AppTheme.body(size: 10, color: const Color(0xB3FDFAF6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Review CTA
            FilledButton(
              onPressed: () => context.push('/review'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryContainer,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
                shadowColor: const Color(0x59E87722),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'عرض السلة',
                    style: AppTheme.body(size: 14, weight: FontWeight.w700, color: AppTheme.onPrimary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_back, size: 18), // RTL: forward arrow points left
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
