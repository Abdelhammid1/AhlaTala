import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/food_image.dart';
import '../../cart/providers/cart_controller.dart';
import '../../cart/widgets/cross_sell_sheet.dart';
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
  const ItemDetailsScreen({super.key, required this.itemId});
  final int itemId;

  @override
  ConsumerState<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends ConsumerState<ItemDetailsScreen> {
  int _qty = 1;
  bool _favorited = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(itemDetailProvider(widget.itemId));
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorView(error: e, onRetry: () => ref.invalidate(itemDetailProvider(widget.itemId))),
        ),
        data: (item) {
          final state = ref.watch(itemConfigurationControllerProvider(item));
          final lineTotal = state.totalPrice * _qty;
          return Stack(
            children: [
              // ---- Scrollable content ----
              ListView(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 64, bottom: 160),
                children: [
                  _TopControlsRow(
                    favorited: _favorited,
                    onFavorite: () => setState(() => _favorited = !_favorited),
                  ),
                  const SizedBox(height: 12),
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
                  for (final g in item.optionGroups)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OptionGroupWidget(item: item, group: g),
                    ),
                ],
              ),
              // ---- Sticky back button ----
              _StickyHeader(item: state.displayName),
              // ---- Bottom quantity + CTA bar ----
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: _BottomCta(
                  qty: _qty,
                  onQtyChange: (n) => setState(() => _qty = n.clamp(1, 20)),
                  totalPrice: lineTotal,
                  canAdd: state.canAddToCart,
                  missing: state.missingRequiredNames,
                  onAdd: () => _addToCart(item.id),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addToCart(int itemId) {
    final detail = ref.read(itemDetailProvider(itemId)).valueOrNull;
    if (detail == null) return;
    final cfg = ref.read(itemConfigurationControllerProvider(detail));
    // The controller adds exactly one line-with-selection each call. The
    // stepper effectively multiplies that: N distinct lines with the same
    // configuration collapse into one line-of-quantity-N inside the cart.
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
    setState(() => _qty = 1);
    Future.microtask(() {
      if (!mounted) return;
      CrossSellSheet.show(context, itemId);
    });
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
