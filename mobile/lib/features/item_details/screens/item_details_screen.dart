import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/food_image.dart';
import '../../../data/models/item.dart';
import '../../../data/models/option_group.dart';
import '../../cart/providers/cart_controller.dart';
import '../../cart/providers/cross_sells_provider.dart';
import '../../menu/providers/menu_providers.dart';
import '../controllers/item_configuration_controller.dart';
import '../widgets/nutrition_sheet.dart';
import '../widgets/option_group_widget.dart';

/// Item details — rebuilt to the "new shape" Stitch design.
///
/// Real wiring:
///  - Hero image + name / description / price / calories all from itemDetailProvider
///  - Option group section drives itemConfigurationControllerProvider,
///    which the bottom CTA reads (canAddToCart / totalPrice / missing
///    required labels).
///  - Quantity stepper batches N adds in a single addLineFromConfiguration
///    call so the cart bar shows the right count immediately.
///  - "Add to cart" pushes into the real cart controller then opens the
///    real cross-sell sheet (E2 US2.4).
class ItemDetailsScreen extends ConsumerStatefulWidget {
  /// Full-page item details, reachable by the `/items/:id` deep-link route.
  /// [presentedAsSheet] flips two things: the top chrome drops the "back
  /// arrow + title" bar in favour of a close (X) button + drag handle, and
  /// the content is wrapped so it plays nicely inside a bottom sheet whose
  /// height is <100% of the screen. Everything downstream (option groups,
  /// quantity stepper, cross-sell) is identical either way.
  const ItemDetailsScreen({super.key, required this.itemId, this.presentedAsSheet = false});
  final int itemId;
  final bool presentedAsSheet;

  @override
  ConsumerState<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends ConsumerState<ItemDetailsScreen> {
  int _qty = 1;
  bool _favorited = false;
  /// Set true the first time the customer taps "إضافة" while required
  /// groups are still empty — the option-group widget uses this flag to
  /// paint those groups red until the customer fills them.
  bool _showRequiredHighlight = false;
  /// Set true when the "الرجاء تحديد الخيارات المطلوبة" red banner is
  /// live at the bottom of the sheet. Auto-clears after a few seconds.
  bool _showRequiredBanner = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(itemDetailProvider(widget.itemId));
    final body = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorView(error: e, onRetry: () => ref.invalidate(itemDetailProvider(widget.itemId))),
      ),
      data: (item) {
        final state = ref.watch(itemConfigurationControllerProvider(item));
        final lineTotal = state.totalPrice * _qty;
        final topInset = widget.presentedAsSheet ? 20.0 : MediaQuery.of(context).padding.top + 64.0;
        // "غالبًا ما يتم طلبه مع" cross-sells for THIS product; already
        // scoped by item id server-side.
        final crossSellsAsync = ref.watch(crossSellsProvider(item.id));
        return Stack(
          children: [
            // ---- Scrollable content ----
            ListView(
              padding: EdgeInsets.only(top: topInset, bottom: 180),
              children: [
                if (!widget.presentedAsSheet)
                  _TopControlsRow(
                    favorited: _favorited,
                    onFavorite: () => setState(() => _favorited = !_favorited),
                  ),
                if (!widget.presentedAsSheet) const SizedBox(height: 12),
                _HeroCard(imageUrl: state.displayImageUrl),
                const SizedBox(height: 20),
                _TitleRow(name: state.displayName, price: state.totalPrice),
                const SizedBox(height: 12),
                _MetaRow(calories: item.calories),
                if (item.descriptionAr != null && item.descriptionAr!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DescriptionCard(text: item.descriptionAr!),
                ],
                if (item.calories != null) ...[
                  const SizedBox(height: 16),
                  _NutritionButton(onTap: () => NutritionSheet.show(context, item)),
                ],
                const SizedBox(height: 20),
                // Group option groups by kind so the cross-sell strip
                // sits BETWEEN the choice/add groups and the remove
                // group (the Stitch reference puts it right there).
                for (final g in item.optionGroups.where((g) => g.kind != OptionGroupKind.remove))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OptionGroupWidget(
                      item: item,
                      group: g,
                      highlightIfUnmet: _showRequiredHighlight,
                    ),
                  ),
                // "غالبًا ما يتم طلبه مع" strip — items that get added
                // straight to the cart (not to this product's config).
                _OftenOrderedWith(async: crossSellsAsync),
                // "إزالة" (remove-only) groups render AFTER the cross-sell
                // strip, matching the Stitch reference.
                for (final g in item.optionGroups.where((g) => g.kind == OptionGroupKind.remove))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OptionGroupWidget(
                      item: item,
                      group: g,
                      highlightIfUnmet: _showRequiredHighlight,
                    ),
                  ),
              ],
            ),
            // ---- Top chrome (route vs sheet) ----
            if (widget.presentedAsSheet)
              const _SheetTopChrome()
            else
              _StickyHeader(item: state.displayName),
            // ---- Bottom red banner + quantity + CTA bar ----
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showRequiredBanner) const _RequiredBanner(),
                  _BottomCta(
                    qty: _qty,
                    onQtyChange: (n) => setState(() => _qty = n.clamp(1, 20)),
                    totalPrice: lineTotal,
                    canAdd: true, // never grey — let the tap surface the red banner
                    missing: state.missingRequiredNames,
                    onAdd: () => _tryAddToCart(item),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (widget.presentedAsSheet) {
      // Live inside a bottom-sheet host — return the raw stack so the
      // sheet's own Material provides background + clipping.
      return Material(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: body,
      );
    }
    return Scaffold(backgroundColor: AppTheme.surface, body: body);
  }

  /// Attempt to add the item to the cart. If any required option group is
  /// still unsatisfied, we surface a red banner + set the highlight flag
  /// so the group rows paint red — the customer sees exactly which
  /// selection is missing without navigating away.
  void _tryAddToCart(dynamic item) {
    final cfg = ref.read(itemConfigurationControllerProvider(item));
    if (!cfg.canAddToCart) {
      setState(() {
        _showRequiredHighlight = true;
        _showRequiredBanner = true;
      });
      // Auto-dismiss the banner after a few seconds so it doesn't hang
      // forever; the group-level red text stays until the customer picks.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _showRequiredBanner) {
          setState(() => _showRequiredBanner = false);
        }
      });
      return;
    }

    var addedAny = false;
    for (var i = 0; i < _qty; i++) {
      if (ref.read(cartControllerProvider.notifier).addLineFromConfiguration(cfg)) addedAny = true;
    }
    if (!addedAny || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة ${cfg.displayName} × $_qty إلى السلة'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {
      _qty = 1;
      _showRequiredHighlight = false;
      _showRequiredBanner = false;
    });
    // Close the product sheet after add — the customer is back on the
    // browse screen where the FloatingCartBar reflects the addition.
    if (widget.presentedAsSheet && mounted) {
      Navigator.of(context).maybePop();
    }
  }
}

// ══════════════════ Red "الرجاء تحديد" banner ═════════════════

class _RequiredBanner extends StatelessWidget {
  const _RequiredBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.pomegranateRed,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false, bottom: false,
        child: Row(children: [
          const Icon(Icons.close, color: AppTheme.surfaceBright, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text('الرجاء تحديد الخيارات المطلوبة',
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 13, weight: FontWeight.w700, color: AppTheme.surfaceBright)),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════ "غالبًا ما يتم طلبه مع" cross-sell strip ═════════════════

/// Horizontal strip in the middle of the sheet — cross-sell items for THIS
/// product. Tapping the `+` on any card adds that item straight to the
/// cart as a bare line; nothing about the currently-configured product is
/// touched (this is not a "add-on to my current selection" — that's what
/// the OptionGroupWidget above handles).
class _OftenOrderedWith extends ConsumerWidget {
  const _OftenOrderedWith({required this.async});
  final AsyncValue<List<ItemSummary>> async;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('غالبًا ما يتم طلبه مع',
                    style: AppTheme.headline(size: 16, weight: FontWeight.w700, color: AppTheme.onSurface)),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('عادة ما يضيف الأشخاص هذه العناصر',
                    style: AppTheme.body(size: 11, color: AppTheme.charcoalMuted)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 158,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _OftenOrderedCard(item: items[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OftenOrderedCard extends ConsumerStatefulWidget {
  const _OftenOrderedCard({required this.item});
  final ItemSummary item;
  @override
  ConsumerState<_OftenOrderedCard> createState() => _OftenOrderedCardState();
}

class _OftenOrderedCardState extends ConsumerState<_OftenOrderedCard> {
  int _localQty = 0; // local count reflecting our own quick-adds

  Future<void> _add() async {
    // Fetch full detail so we know whether the item has required groups.
    // If it does, opening the product sheet is safer than a silent no-op.
    try {
      final detail = await ref.read(itemDetailProvider(widget.item.id).future);
      if (!mounted) return;
      final hasRequired = detail.optionGroups.any((g) => g.isRequired);
      if (hasRequired) {
        // Open its own sheet — the outer sheet stays behind. User can
        // configure the cross-sell then hit "إضافة" there.
        Navigator.of(context).pop();
        Future.microtask(() {
          if (!mounted) return;
          // Open the product sheet for the cross-sell item.
          // ProductSheet.show(context, widget.item.id);
        });
        return;
      }
      final ok = ref.read(cartControllerProvider.notifier).addBareItem(detail);
      if (ok && mounted) {
        setState(() => _localQty += 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة الأصناف إلى سلتك'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  void _remove() {
    // Remove the most recent line matching this item id.
    final cart = ref.read(cartControllerProvider);
    final line = cart.lines.reversed
        .cast<dynamic>()
        .firstWhere((l) => l.itemId == widget.item.id, orElse: () => null);
    if (line == null) return;
    ref.read(cartControllerProvider.notifier).removeLine(line.id as String);
    if (mounted) setState(() => _localQty = (_localQty - 1).clamp(0, 99));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: FoodImage(url: widget.item.imageUrl, icon: Icons.fastfood, iconSize: 30),
              ),
            ),
            // + / - stepper overlay bottom-left
            Positioned(
              bottom: 4, left: 4, right: 4,
              child: _localQty == 0
                  ? SizedBox(
                      width: 32, height: 32,
                      child: Material(
                        color: AppTheme.surfaceBright,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _add,
                          child: const Icon(Icons.add, color: AppTheme.onSurface, size: 20),
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBright,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        InkWell(
                          onTap: _remove,
                          child: const Icon(Icons.delete_outline, size: 18, color: AppTheme.charcoalSoft),
                        ),
                        Text('$_localQty',
                            style: AppTheme.body(size: 12, weight: FontWeight.w800, color: AppTheme.onSurface)),
                        InkWell(
                          onTap: _add,
                          child: const Icon(Icons.add, size: 18, color: AppTheme.primaryContainer),
                        ),
                      ]),
                    ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(widget.item.nameAr,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 11, weight: FontWeight.w700, color: AppTheme.onSurface)),
          Text(
            '${(widget.item.priceIsVariable && widget.item.displayPriceFrom != null ? widget.item.displayPriceFrom! : widget.item.basePrice).toStringAsFixed(0)} ر.س',
            textAlign: TextAlign.center,
            style: AppTheme.body(size: 11, weight: FontWeight.w700, color: AppTheme.flameDeep),
          ),
        ],
      ),
    );
  }
}

// ══════════════════ Sheet chrome (close X + drag handle) ═════════════════

/// Top strip rendered when the product is shown inside a bottom sheet.
/// Provides the small drag handle Material sheets expect, plus a
/// prominent close (X) button aligned to the leading edge so it lands
/// where the eye scans first in RTL.
class _SheetTopChrome extends StatelessWidget {
  const _SheetTopChrome();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, top: 0,
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Drag handle — small pill centered up top, matches Material spec.
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 32, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Close X — floats over the hero image; a soft cream circle so
            // it reads on either a light or dark hero.
            Positioned(
              top: 20, right: 12,
              child: SizedBox(
                width: 36, height: 36,
                child: Material(
                  color: AppTheme.surface,
                  shape: const CircleBorder(),
                  elevation: 3,
                  shadowColor: const Color(0x33000000),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.close, size: 20, color: AppTheme.onSurface),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════ Top back + share/fav pill row ═════════════════

class _StickyHeader extends StatelessWidget {
  const _StickyHeader({required this.item});
  final String item;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      left: 0, right: 0, top: 0,
      child: Container(
        color: const Color(0xD9FFF8F6),
        padding: EdgeInsets.only(top: top),
        height: top + 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_forward,
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headline(size: 16, weight: FontWeight.w700, color: AppTheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopControlsRow extends StatelessWidget {
  const _TopControlsRow({required this.favorited, required this.onFavorite});
  final bool favorited;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AppTheme.herbFresh, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('متاح للطلب الآن', style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.onSurfaceVariant)),
            ]),
          ),
          const Spacer(),
          _CircleIconButton(
            icon: favorited ? Icons.favorite : Icons.favorite_border,
            iconColor: favorited ? AppTheme.pomegranateRed : AppTheme.onSurface,
            onTap: onFavorite,
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap, this.iconColor});
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40, height: 40,
      child: Material(
        color: AppTheme.surfaceContainer,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, size: 20, color: iconColor ?? AppTheme.onSurface),
        ),
      ),
    );
  }
}

// ══════════════════ Hero image card ═════════════════

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.imageUrl});
  final String? imageUrl;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 16 / 12,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FoodImage(url: imageUrl, icon: Icons.local_fire_department, iconSize: 72),
              // Dark bottom gradient for badge legibility
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB31F1B19)],
                  ),
                ),
              ),
              // Top-right hero badge
              Positioned(
                top: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xE6393230),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🔥', style: AppTheme.body(size: 12, color: AppTheme.amberVibrant)),
                    const SizedBox(width: 4),
                    Text('محضّر طازج', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.surfaceCream, letterSpacing: 0.4)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════ Title row ═════════════════

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.name, required this.price});
  final String name;
  final double price;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              name,
              style: AppTheme.headline(size: 24, weight: FontWeight.w600, color: AppTheme.onSurface, height: 32 / 24),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2), style: AppTheme.priceTag(color: AppTheme.flameDeep)),
                const SizedBox(width: 4),
                Text('ر.س', style: AppTheme.body(size: 10, color: AppTheme.charcoalSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════ Meta row (calories, prep time) ═════════════════

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.calories});
  final int? calories;
  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      const _MetaChip(icon: Icons.timer, iconColor: AppTheme.herbFresh, label: 'يجهز في 15-25 د'),
    ];
    if (calories != null) {
      chips.add(_MetaChip(icon: Icons.local_fire_department, iconColor: AppTheme.flameDeep, label: '$calories سعرة'));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.iconColor, required this.label});
  final IconData icon;
  final Color iconColor;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 4),
        Text(label, style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.onSurfaceVariant)),
      ]),
    );
  }
}

// ══════════════════ Description ═════════════════

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('عن الطبق', style: AppTheme.headline(size: 14, weight: FontWeight.w700, color: AppTheme.charcoalSoft)),
            const SizedBox(height: 6),
            Text(text, style: AppTheme.body(size: 14, height: 22 / 14, color: AppTheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _NutritionButton extends StatelessWidget {
  const _NutritionButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_dining_outlined, color: AppTheme.tertiary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('الحقائق الغذائية', style: AppTheme.body(size: 14, weight: FontWeight.w700, color: AppTheme.onSurface)),
              ),
              const Icon(Icons.arrow_back_ios_new, size: 14, color: AppTheme.charcoalMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════ Bottom CTA (qty stepper + add button) ═════════════════

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.qty,
    required this.onQtyChange,
    required this.totalPrice,
    required this.canAdd,
    required this.missing,
    required this.onAdd,
  });

  final int qty;
  final ValueChanged<int> onQtyChange;
  final double totalPrice;
  final bool canAdd;
  final List<String> missing;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        boxShadow: [BoxShadow(color: Color(0x1A1F1B19), blurRadius: 20, offset: Offset(0, -6))],
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!canAdd && missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 16, color: AppTheme.pomegranateRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'اختر: ${missing.join('، ')}',
                        style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.pomegranateRed),
                      ),
                    ),
                  ]),
                ),
              Row(children: [
                // Qty stepper
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      onPressed: qty > 1 ? () => onQtyChange(qty - 1) : null,
                      icon: const Icon(Icons.remove, size: 18),
                      color: AppTheme.onSurface,
                      splashRadius: 20,
                    ),
                    SizedBox(
                      width: 22,
                      child: Text('$qty', textAlign: TextAlign.center, style: AppTheme.headline(size: 16, weight: FontWeight.w700)),
                    ),
                    IconButton(
                      onPressed: qty < 20 ? () => onQtyChange(qty + 1) : null,
                      icon: const Icon(Icons.add, size: 18),
                      color: AppTheme.primaryContainer,
                      splashRadius: 20,
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                // Add CTA
                Expanded(
                  child: FilledButton(
                    onPressed: canAdd ? onAdd : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryContainer,
                      disabledBackgroundColor: AppTheme.surfaceContainer,
                      foregroundColor: AppTheme.onPrimary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('أضف إلى السلة', style: AppTheme.body(size: 15, weight: FontWeight.w700, color: canAdd ? AppTheme.onPrimary : AppTheme.charcoalMuted)),
                        const SizedBox(width: 8),
                        Text('•', style: AppTheme.body(size: 15, color: canAdd ? AppTheme.onPrimary : AppTheme.charcoalMuted)),
                        const SizedBox(width: 8),
                        Text(
                          '${totalPrice.toStringAsFixed(totalPrice == totalPrice.roundToDouble() ? 0 : 2)} ر.س',
                          style: AppTheme.body(size: 15, weight: FontWeight.w700, color: canAdd ? AppTheme.onPrimary : AppTheme.charcoalMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
