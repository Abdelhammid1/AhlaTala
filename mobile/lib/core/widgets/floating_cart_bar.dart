import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../../features/cart/providers/cart_controller.dart';
import '../../features/cart/providers/settings_provider.dart';
import 'food_image.dart';

/// Floating cart pill matching the Stitch _1 / _9 mockup.
///
/// Two visual states in one component:
///  • **In-progress toward free delivery** (subtotal < threshold) — cream
///    body with an inner tinted progress track; a short line above the
///    row nudges the customer with how much more they need to add.
///  • **Free delivery unlocked** (subtotal ≥ threshold) — the bar swaps
///    to the herb-green celebration bg and shows "توصيل مجاني".
///
/// The pill also renders up to three mini item thumbnails from the cart,
/// so the customer can eyeball what's inside without opening review.
/// Every value comes from real providers (cart lines + settings).
class FloatingCartBar extends ConsumerWidget {
  const FloatingCartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartControllerProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final subtotal = state.subtotal;
    final itemCount = state.lines.fold<int>(0, (n, l) => n + l.quantity);
    if (itemCount == 0) return const SizedBox.shrink();

    // Fall back to the well-known default while the settings roundtrip is in
    // flight — the bar is a live piece of chrome and shouldn't blink.
    final threshold = settingsAsync.maybeWhen(
      data: (s) => s.freeDeliveryThreshold,
      orElse: () => 60.0,
    );
    final progress = threshold <= 0 ? 1.0 : (subtotal / threshold).clamp(0.0, 1.0);
    final unlocked = progress >= 1.0;
    final remaining = (threshold - subtotal).clamp(0.0, threshold);

    // Up to 3 thumbs — one per line, in insertion order.
    final thumbs = state.lines.take(3).map((l) => l.imageUrl).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- Main pill (orange gradient) ----
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [AppTheme.flameDeep, AppTheme.primaryContainer],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x40E87722), blurRadius: 22, offset: Offset(0, 10)),
              ],
            ),
            child: Row(
              children: [
                // Bag with count badge
                SizedBox(
                  width: 44, height: 44,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBright.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_bag, size: 22, color: AppTheme.onPrimary),
                    ),
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.pomegranateRed,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
                        ),
                        child: Text('$itemCount',
                            style: AppTheme.body(size: 10, weight: FontWeight.w800, color: AppTheme.surfaceBright)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                // Mini thumbnails — visible identity of what's in the cart
                if (thumbs.isNotEmpty)
                  SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < thumbs.length; i++)
                          Padding(
                            padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 32, height: 32,
                                child: FoodImage(url: thumbs[i], icon: Icons.fastfood, iconSize: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                // Count + subtotal
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$itemCount أصناف في السلة',
                          style: AppTheme.body(size: 11, weight: FontWeight.w600, color: const Color(0xE6FDFAF6)),
                          overflow: TextOverflow.ellipsis),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            subtotal.toStringAsFixed(subtotal == subtotal.roundToDouble() ? 0 : 2),
                            style: AppTheme.priceTag(color: AppTheme.surfaceBright, size: 18),
                          ),
                          const SizedBox(width: 4),
                          Text('ر.س', style: AppTheme.body(size: 10, color: const Color(0xB3FDFAF6))),
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
                    backgroundColor: AppTheme.surfaceBright,
                    foregroundColor: AppTheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('عرض السلة',
                          style: AppTheme.body(size: 13, weight: FontWeight.w800, color: AppTheme.primaryContainer)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_back, size: 16, color: AppTheme.primaryContainer),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ---- Free-delivery progress bar ----
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: unlocked ? AppTheme.herbFresh.withValues(alpha: 0.14) : AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(
                unlocked ? Icons.celebration : Icons.local_shipping_outlined,
                size: 14,
                color: unlocked ? AppTheme.herbFresh : AppTheme.charcoalMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    if (unlocked)
                      TextSpan(
                        text: 'مبروك! حصلت على ',
                        style: AppTheme.body(size: 11, weight: FontWeight.w600, color: AppTheme.charcoalSoft),
                      )
                    else
                      TextSpan(
                        text: 'أضف ${remaining.toStringAsFixed(remaining == remaining.roundToDouble() ? 0 : 2)} ر.س لتحصل على ',
                        style: AppTheme.body(size: 11, weight: FontWeight.w600, color: AppTheme.charcoalSoft),
                      ),
                    TextSpan(
                      text: 'توصيل مجاني',
                      style: AppTheme.body(
                        size: 11,
                        weight: FontWeight.w800,
                        color: unlocked ? AppTheme.herbFresh : AppTheme.flameDeep,
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(progress * 100).round()}%',
                  style: AppTheme.body(
                    size: 10,
                    weight: FontWeight.w800,
                    color: unlocked ? AppTheme.herbFresh : AppTheme.flameDeep,
                  )),
            ]),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppTheme.outlineVariant.withValues(alpha: 0.35),
              valueColor: AlwaysStoppedAnimation(unlocked ? AppTheme.herbFresh : AppTheme.primaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
