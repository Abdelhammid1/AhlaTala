import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/floating_cart_bar.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/stitch_bottom_nav.dart';
import '../../../data/models/item.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../cart/providers/cart_controller.dart';
import '../../home/providers/promo_providers.dart';
import '../../cart/models/fulfillment.dart';
import '../../loyalty/providers/loyalty_providers.dart';
import '../providers/menu_providers.dart';

/// Home screen — rebuilt to the "new shape" Stitch design.
///
/// Every visual element is wired to a real provider:
///  - Location chip pulls the current fulfillment address (when delivery is
///    chosen and an address is saved), else falls back to the delivery hint.
///  - Points chip watches the signed-in customer's balance provider.
///  - Delivery/pickup pill toggle mutates `cartControllerProvider` fulfillment.
///  - Hero banner is static copy (brand messaging, always shown).
///  - Category chip scroller is the real categoriesProvider.
///  - "Most ordered" is the real mostOrderedProvider; each add button calls
///    the real `addBareItem` (falls back to item details if the item has
///    required option groups).
///  - Floating cart bar is fed by cartControllerProvider (auto-hides when
///    the cart is empty).
///  - Bottom nav is the shared StitchBottomNav.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaTop = MediaQuery.of(context).padding.top;
    // Cart state drives visibility of the floating cart bar → shift page bottom
    // padding so the last product tile isn't hidden underneath it.
    final cartLines = ref.watch(cartControllerProvider).lines.length;
    final hasCartBar = cartLines > 0;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // ------ Scrollable content ------
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(offersProvider);
              ref.invalidate(mostOrderedProvider);
              ref.invalidate(categoriesProvider);
            },
            child: ListView(
              padding: EdgeInsets.only(top: mediaTop + 80, bottom: hasCartBar ? 210 : 96),
              children: const [
                _FulfillmentToggle(),
                SizedBox(height: 16),
                _HeroBanner(),
                SizedBox(height: 24),
                _CategoriesRow(),
                SizedBox(height: 20),
                _MostOrderedList(),
                SizedBox(height: 24),
                _OffersCarousel(),
                SizedBox(height: 32),
              ],
            ),
          ),
          // ------ Sticky glass header ------
          const _StickyHeader(),
          // ------ Floating cart bar + bottom nav ------
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasCartBar) const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: FloatingCartBar(),
                ),
                const StitchBottomNav(active: StitchNavTab.home),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Sticky glass header — location + points + profile
// ═════════════════════════════════════════════════════════════════════

class _StickyHeader extends ConsumerWidget {
  const _StickyHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaTop = MediaQuery.of(context).padding.top;
    final fulfillment = ref.watch(cartControllerProvider).fulfillment;
    final address = fulfillment.address ?? 'حي النرجس، الرياض';

    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xD9FFF8F6), // surface at ~85% opacity
          boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1))],
        ),
        padding: EdgeInsets.only(top: mediaTop),
        child: SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Location button
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      // Open profile → saved addresses management as the
                      // natural landing spot for changing the delivery
                      // location. (Full address picker with a map is a
                      // future add.)
                      GoRouter.of(context).push('/profile');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: [
                            const Icon(Icons.near_me, color: AppTheme.flameDeep, size: 15),
                            const SizedBox(width: 4),
                            Text('التوصيل إلى',
                                style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.charcoalMuted, letterSpacing: 0.4)),
                          ]),
                          const SizedBox(height: 2),
                          Row(children: [
                            Flexible(
                              child: Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.body(size: 14, weight: FontWeight.w600, color: AppTheme.onSurface),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.onSurfaceVariant),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
                const _PointsChip(),
                const SizedBox(width: 8),
                const _ProfileButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PointsChip extends ConsumerWidget {
  const _PointsChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    // Only render for signed-in users; guests don't have a points balance
    // to show. Kept hidden — never shows a fake "0 نقطة".
    if (session == null) return const SizedBox.shrink();
    final async = ref.watch(customerBalanceProvider(session.customer.phone));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (bal) {
        if (bal == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCream,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.stars, color: AppTheme.amberVibrant, size: 16),
            const SizedBox(width: 4),
            Text(
              '${bal.pointsBalance} نقطة',
              style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.charcoalSoft),
            ),
          ]),
        );
      },
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44, height: 44,
      child: IconButton(
        onPressed: () => context.push('/profile'),
        iconSize: 32,
        padding: EdgeInsets.zero,
        icon: Container(
          decoration: const BoxDecoration(
            color: AppTheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.person, color: AppTheme.onPrimary, size: 24),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Delivery / pickup pill toggle
// ═════════════════════════════════════════════════════════════════════

class _FulfillmentToggle extends ConsumerWidget {
  const _FulfillmentToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ful = ref.watch(cartControllerProvider).fulfillment;
    // Default the visual selection to delivery when the customer hasn't
    // chosen yet — matches how the Stitch design opens.
    final isDelivery = ful.type == FulfillmentType.delivery || ful.type == FulfillmentType.none;

    void selectDelivery() =>
        ref.read(cartControllerProvider.notifier).setFulfillment(FulfillmentType.delivery, address: ful.address);
    void selectPickup() =>
        ref.read(cartControllerProvider.notifier).setFulfillment(FulfillmentType.pickup);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCreamSubtle,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          Expanded(
            child: _TogglePill(
              selected: isDelivery,
              icon: Icons.two_wheeler,
              iconColor: AppTheme.amberVibrant,
              label: 'توصيل سريع',
              trailing: '25-35 د',
              onTap: selectDelivery,
            ),
          ),
          Expanded(
            child: _TogglePill(
              selected: !isDelivery,
              icon: Icons.storefront,
              iconColor: AppTheme.onSurfaceVariant,
              label: 'استلام من الفرع',
              onTap: selectPickup,
            ),
          ),
        ]),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.selected,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final bool selected;
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.charcoalSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x1A1F1B19), blurRadius: 4)]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? iconColor : AppTheme.charcoalMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.body(
                size: 14, weight: FontWeight.w700,
                color: selected ? AppTheme.surfaceBright : AppTheme.charcoalMuted,
              ),
            ),
            if (trailing != null && selected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x33FDFAF6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trailing!,
                  style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.surfaceBright, letterSpacing: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Hero banner — always-visible brand card
// ═════════════════════════════════════════════════════════════════════

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [AppTheme.flameDeep, AppTheme.primary, AppTheme.charcoalSoft],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x59E65100), blurRadius: 24, offset: Offset(0, 12))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Ambient blur accent
              Positioned(
                left: -24, bottom: -24, width: 144, height: 144,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.amberVibrant.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "المطعم يستقبل الطلبات الآن" pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.goldLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department, size: 14, color: AppTheme.goldLight),
                      const SizedBox(width: 4),
                      Text(
                        'المطعم يستقبل الطلبات الآن',
                        style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.goldLight, letterSpacing: 0.4),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'من على الفحم\nلباب بيتك 🔥',
                    style: AppTheme.headline(size: 24, weight: FontWeight.w700, color: AppTheme.surfaceBright, height: 32 / 24),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      'مشاوي طازجة، ركن شاورما أصلي، وعصائر منعشة محضّرة بكل حب يومياً.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(size: 12, color: const Color(0xE6F7F3EE)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Categories horizontal chip scroller
// ═════════════════════════════════════════════════════════════════════

class _CategoriesRow extends ConsumerWidget {
  const _CategoriesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('التصنيفات', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
              async.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (cats) => Text('${cats.length} قسم', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.charcoalMuted, letterSpacing: 0.4)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: async.when(
            loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
            data: (cats) {
              if (cats.isEmpty) return const SizedBox.shrink();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cats.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _CategoryChip(
                      selected: true,
                      label: 'الكل',
                      onTap: () {},
                    );
                  }
                  final c = cats[i - 1];
                  return _CategoryChip(
                    selected: false,
                    label: c.nameAr,
                    onTap: () => context.push('/categories/${c.id}', extra: c.nameAr),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.selected, required this.label, required this.onTap});
  final bool selected;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.charcoalSoft : AppTheme.surfaceCreamSubtle,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? const [BoxShadow(color: Color(0x1A1F1B19), blurRadius: 4)] : [],
        ),
        child: Text(
          label,
          style: AppTheme.body(
            size: 12, weight: FontWeight.w700,
            color: selected ? AppTheme.onPrimary : AppTheme.charcoalSoft,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Most-ordered vertical list
// ═════════════════════════════════════════════════════════════════════

class _MostOrderedList extends ConsumerWidget {
  const _MostOrderedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mostOrderedProvider);
    return async.when(
      loading: () => const _SectionSkeleton(title: 'الأكثر طلباً 🔥'),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorView(error: e, onRetry: () => ref.invalidate(mostOrderedProvider)),
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.local_fire_department, size: 22, color: AppTheme.flameDeep),
                    const SizedBox(width: 4),
                    Text('الأكثر طلباً 🔥', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
                  ]),
                  Text('عرض الكل', style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.flameDeep)),
                ],
              ),
            ),
            ...items.take(6).map((it) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _DishTile(item: it),
                )),
          ],
        );
      },
    );
  }
}

/// Horizontal food card matching the Stitch dish tile.
class _DishTile extends ConsumerWidget {
  const _DishTile({required this.item});
  final ItemSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/items/${item.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 96, height: 96,
                child: FoodImage(url: item.imageUrl, icon: Icons.local_fire_department, iconSize: 36),
              ),
            ),
            const SizedBox(width: 12),
            // Text column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.nameAr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.headline(size: 16, weight: FontWeight.w700, color: AppTheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  // ItemSummary carries only category + price hints — a
                  // short subtitle is derived from those. The fuller
                  // description lives on ItemDetail (the details page).
                  Text(
                    item.priceIsVariable && item.displayPriceFrom != null
                        ? 'أحجام مختلفة تبدأ من ${item.displayPriceFrom!.toStringAsFixed(0)} ريال'
                        : 'جاهز في 15-25 د',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Price
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              item.priceIsVariable && item.displayPriceFrom != null
                                  ? item.displayPriceFrom!.toStringAsFixed(0)
                                  : item.basePrice.toStringAsFixed(0),
                              style: AppTheme.priceTag(color: AppTheme.flameDeep),
                            ),
                            const SizedBox(width: 4),
                            Text('ر.س', style: AppTheme.body(size: 10, color: AppTheme.charcoalMuted)),
                          ],
                        ),
                      ),
                      // Add button — either quick-add or push to details
                      _AddButton(item: item),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends ConsumerWidget {
  const _AddButton({required this.item});
  final ItemSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 32, height: 32,
      child: Material(
        color: AppTheme.primaryContainer,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x4CE87722),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            // Fetch the full detail so we know whether required options exist;
            // items with option groups always go through the details screen.
            try {
              final detail = await ref.read(itemDetailProvider(item.id).future);
              if (!context.mounted) return;
              final hasRequired = detail.optionGroups.any((g) => g.isRequired);
              if (hasRequired) {
                context.push('/items/${item.id}');
                return;
              }
              final ok = ref.read(cartControllerProvider.notifier).addBareItem(detail);
              if (!context.mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تمت إضافة ${detail.nameAr}'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تعذّرت الإضافة، حاول لاحقاً')),
              );
            }
          },
          child: const Icon(Icons.add, color: AppTheme.onPrimary, size: 20),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Offers carousel (kept from before but visually reskinned)
// ═════════════════════════════════════════════════════════════════════

class _OffersCarousel extends ConsumerWidget {
  const _OffersCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(offersProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (offers) {
        if (offers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                const Icon(Icons.local_offer, color: AppTheme.amberVibrant, size: 22),
                const SizedBox(width: 4),
                Text('عروض الأسبوع', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
              ]),
            ),
            SizedBox(
              height: 150,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.88),
                padEnds: false,
                itemCount: offers.length,
                itemBuilder: (_, i) {
                  final o = offers[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12, left: 4),
                    child: InkWell(
                      onTap: o.linkedItemId != null ? () => context.push('/items/${o.linkedItemId}') : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topRight, end: Alignment.bottomLeft,
                            colors: [AppTheme.flameDeep, AppTheme.primary],
                          ),
                          boxShadow: const [BoxShadow(color: Color(0x33E65100), blurRadius: 12, offset: Offset(0, 6))],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(o.titleAr, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.headline(size: 20, weight: FontWeight.w700, color: AppTheme.surfaceBright)),
                            if (o.descriptionAr != null && o.descriptionAr!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(o.descriptionAr!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 12, color: const Color(0xE6FDFAF6))),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
}
