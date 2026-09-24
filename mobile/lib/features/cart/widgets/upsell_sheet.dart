import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/food_image.dart';
import '../../../data/models/item.dart';
import '../../home/providers/promo_providers.dart';
import '../../menu/providers/menu_providers.dart';
import '../providers/cart_controller.dart';

/// "لا تفوت الفرصة" upsell popup shown when the customer taps
/// "اذهب للدفع" on the review screen. Grid of cross-sell items the
/// customer can add to the cart in-place before continuing.
///
/// Returns via [Navigator.pop]:
///   - `true`   → the customer tapped the sheet's own "اذهب للدفع"
///                → caller proceeds with the order submit
///   - anything else (drag-down / back / ×) → caller aborts the submit
class UpsellSheet {
  const UpsellSheet._();

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x99000000),
      builder: (_) => const _UpsellSheetBody(),
    );
  }
}

class _UpsellSheetBody extends ConsumerWidget {
  const _UpsellSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mostOrderedProvider);
    final cartItemIds = ref.watch(cartControllerProvider).lines.map((l) => l.itemId).toSet();
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Material(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Drag handle
                const SizedBox(height: 8),
                Container(
                  width: 32, height: 4,
                  decoration: BoxDecoration(color: AppTheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 8),
                // Header: title + close X on the leading edge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(false),
                      icon: const Icon(Icons.close, size: 22),
                      color: AppTheme.charcoalSoft,
                      splashRadius: 20,
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('لا تفوت الفرصة!',
                            style: AppTheme.headline(size: 18, weight: FontWeight.w800, color: AppTheme.onSurface)),
                        const SizedBox(height: 2),
                        Text('فرصتك لإضافة المزيد لطلبك',
                            style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
                      ],
                    ),
                    const SizedBox(width: 40), // symmetry with the close button
                  ]),
                ),
                const SizedBox(height: 8),
                // Grid of cross-sell items, skipping anything already in the cart.
                Expanded(
                  child: async.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (items) {
                      final picks = items.where((it) => !cartItemIds.contains(it.id)).toList();
                      if (picks.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('طلبك جاهز — لا يوجد أصناف إضافية لعرضها',
                                textAlign: TextAlign.center,
                                style: AppTheme.body(size: 13, color: AppTheme.charcoalMuted)),
                          ),
                        );
                      }
                      return GridView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: picks.length,
                        itemBuilder: (_, i) => _UpsellCard(item: picks[i]),
                      );
                    },
                  ),
                ),
                // Sticky bottom "اذهب للدفع" button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.tertiaryFixedDim,
                      foregroundColor: AppTheme.onSurface,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('اذهب للدفع',
                        style: AppTheme.body(size: 15, weight: FontWeight.w800, color: AppTheme.onSurface)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One item in the upsell grid — tap `+` to add straight to the cart.
class _UpsellCard extends ConsumerStatefulWidget {
  const _UpsellCard({required this.item});
  final ItemSummary item;
  @override
  ConsumerState<_UpsellCard> createState() => _UpsellCardState();
}

class _UpsellCardState extends ConsumerState<_UpsellCard> {
  bool _added = false;

  Future<void> _add() async {
    try {
      final detail = await ref.read(itemDetailProvider(widget.item.id).future);
      if (!mounted) return;
      // If the item requires option choices we can't quick-add — that
      // case is rare in cross-sells (sauces/sides), so we just tell
      // the customer to open the item.
      if (detail.optionGroups.any((g) => g.isRequired)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('يحتاج ${detail.nameAr} خيارات — افتحه من القائمة الرئيسية'),
              duration: const Duration(seconds: 2)),
        );
        return;
      }
      final ok = ref.read(cartControllerProvider.notifier).addBareItem(detail);
      if (ok && mounted) {
        setState(() => _added = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: FoodImage(url: widget.item.imageUrl, icon: Icons.fastfood, iconSize: 28),
            ),
          ),
          Positioned(
            bottom: 6, left: 6,
            child: SizedBox(
              width: 30, height: 30,
              child: Material(
                color: _added ? AppTheme.herbFresh : AppTheme.surfaceBright,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _add,
                  child: Icon(
                    _added ? Icons.check : Icons.add,
                    size: 18,
                    color: _added ? AppTheme.surfaceBright : AppTheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(widget.item.nameAr,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTheme.body(size: 11, weight: FontWeight.w700, color: AppTheme.onSurface)),
        Text(
          '${(widget.item.priceIsVariable && widget.item.displayPriceFrom != null ? widget.item.displayPriceFrom! : widget.item.basePrice).toStringAsFixed(widget.item.basePrice == widget.item.basePrice.roundToDouble() ? 0 : 2)} ر.س',
          textAlign: TextAlign.center,
          style: AppTheme.body(size: 11, weight: FontWeight.w800, color: AppTheme.flameDeep),
        ),
      ],
    );
  }
}
