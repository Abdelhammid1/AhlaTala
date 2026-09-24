import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/floating_cart_bar.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/stitch_bottom_nav.dart';
// go_router import kept: pushed by _CategoryChip for category browsing.

import '../../../data/models/category.dart';
import '../../../data/models/item.dart';
import '../../../data/models/offer.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../cart/providers/cart_controller.dart';
import '../../home/providers/promo_providers.dart';
import '../../item_details/widgets/product_sheet.dart';
import '../../../data/models/session.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../cart/models/fulfillment.dart';
import '../../loyalty/providers/loyalty_providers.dart';
import '../../profile/screens/addresses_screen.dart';
import '../providers/menu_providers.dart';

/// Home screen — HungerStation-style scrollspy shape.
///
/// The screen is one long CustomScrollView broken into stacked sections
/// that map 1:1 to a horizontally-scrollable tab bar pinned near the
/// top. Tabs, in order:
///
///   1. عروض مميزة   — horizontal cards from offersProvider
///   2. الأكثر مبيعاً — horizontal cards from top-4 of mostOrderedProvider
///   3. الأكثر طلباً  — vertical dish tiles from the rest of mostOrdered
///   4..N. one tab per DB category (categoriesProvider), each showing
///           that category's items as a vertical list (categoryItemsProvider)
///
/// Behaviour:
///   • Tapping any tab smooth-scrolls to that section, leaving the sticky
///     header + tab bar exposed.
///   • As the user scrolls, the tab bar auto-highlights whichever section
///     is currently anchored just below the tab bar (scrollspy). The
///     highlighted tab also auto-centers horizontally inside the tab
///     rail so it's always visible.
///   • The scroll listener updates once per frame at most (schedule-guarded)
///     so long scrolls stay smooth.
///
/// Every value is real: nothing static above sample data — all cards,
/// counts, and item rows come from the same providers the rest of the
/// app already reads.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _scrollCtrl = ScrollController();
  final _tabBarScrollCtrl = ScrollController();

  /// Per-tab id → GlobalKey. Reused across builds so the section widgets
  /// don't lose state and the scrollspy can measure offsets reliably.
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _tabKeys = {};

  int _activeTab = 0;
  bool _scrollListenerScheduled = false;
  /// Set true while _scrollToSection is animating the main scroll. The
  /// scrollspy listener skips its work during that window so a tap on a
  /// far-away tab doesn't flip the highlight through every intermediate
  /// section as it flies past.
  bool _programmaticScroll = false;

  static const double _tabBarHeight = 48;
  static const double _headerHeight = 80;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScrollTick);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScrollTick);
    _scrollCtrl.dispose();
    _tabBarScrollCtrl.dispose();
    super.dispose();
  }

  GlobalKey _sectionKey(String id) => _sectionKeys.putIfAbsent(id, () => GlobalKey());
  GlobalKey _tabKey(String id) => _tabKeys.putIfAbsent(id, () => GlobalKey());

  /// Rate-limited scroll listener: coalesces bursts into one recompute
  /// per frame so the scrollspy work happens at most 60fps instead of
  /// on every pixel of a fast fling. Also skipped entirely while a
  /// programmatic tap-to-scroll is animating.
  void _onScrollTick() {
    if (_scrollListenerScheduled || _programmaticScroll) return;
    _scrollListenerScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollListenerScheduled = false;
      if (_programmaticScroll) return;
      _recomputeActiveTab();
    });
  }

  /// Walk each section's key, find the last one whose top edge is at
  /// (or above) the sticky tab bar's bottom — that's the section the
  /// customer is currently "inside".
  void _recomputeActiveTab() {
    if (!mounted) return;
    final mediaTop = MediaQuery.of(context).padding.top;
    // Sticky-region bottom = glass header (headerHeight) + tab bar height.
    // MediaTop is inside the header, not added on top of it.
    final double stickyBottom = mediaTop + _headerHeight + _tabBarHeight;
    final tabs = _computeTabs(_lastCategories);
    int detected = 0;
    for (int i = 0; i < tabs.length; i++) {
      final key = _sectionKeys[tabs[i].id];
      final ctx = key?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) continue;
      final topInWindow = box.localToGlobal(Offset.zero).dy;
      // 12px slack so a tab flips a hair before its section is fully
      // pinned; feels more responsive.
      if (topInWindow <= stickyBottom + 12) {
        detected = i;
      } else {
        break;
      }
    }
    if (detected != _activeTab) {
      setState(() => _activeTab = detected);
      _centerActiveTabInBar(detected);
    }
  }

  /// Center the active tab horizontally inside the tab bar. Uses the
  /// tab-bar's own ScrollController directly (never `ensureVisible`,
  /// which would climb the tree and scroll the outer CustomScrollView
  /// too — that's what caused the "tap goes down and up in a sec" bug).
  void _centerActiveTabInBar(int index) {
    if (!_tabBarScrollCtrl.hasClients) return;
    final tabs = _computeTabs(_lastCategories);
    if (index < 0 || index >= tabs.length) return;
    final ctx = _tabKeys[tabs[index].id]?.currentContext;
    if (ctx == null) return;
    final RenderObject? obj = ctx.findRenderObject();
    if (obj is! RenderBox) return;
    // Find the enclosing Scrollable (the tab bar) — its RenderObject
    // gives us the viewport width and lets us translate the tab's
    // origin into scroll-frame coordinates.
    final scrollableState = Scrollable.maybeOf(ctx);
    if (scrollableState == null) return;
    final scrollableRO = scrollableState.context.findRenderObject();
    if (scrollableRO is! RenderBox) return;
    final tabOriginInViewport = obj.localToGlobal(Offset.zero, ancestor: scrollableRO);
    final viewportWidth = scrollableRO.size.width;
    final tabWidth = obj.size.width;
    // Current offset + how far the tab's *center* is from the viewport's
    // left edge, minus half the viewport width → tab center lands at
    // viewport center.
    final target = _tabBarScrollCtrl.offset
        + tabOriginInViewport.dx + tabWidth / 2
        - viewportWidth / 2;
    final clamped = target.clamp(0.0, _tabBarScrollCtrl.position.maxScrollExtent);
    _tabBarScrollCtrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _scrollToSection(int index) async {
    final tabs = _computeTabs(_lastCategories);
    if (index < 0 || index >= tabs.length) return;
    final ctx = _sectionKeys[tabs[index].id]?.currentContext;
    if (ctx == null) return;

    // Compute the exact scroll offset that lands the section's top edge
    // just under the sticky region. RenderAbstractViewport gives an
    // accurate offset even with earlier slivers of variable height above.
    final RenderObject? obj = ctx.findRenderObject();
    if (obj == null || !_scrollCtrl.hasClients) return;
    final viewport = RenderAbstractViewport.of(obj);
    final reveal = viewport.getOffsetToReveal(obj, 0.0);
    final mediaTop = MediaQuery.of(context).padding.top;
    final targetOffset = (reveal.offset - (mediaTop + _headerHeight + _tabBarHeight))
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);

    // Flip highlight + center the tab BEFORE the scroll starts. During
    // the animation the scroll listener is muted, so no bouncing.
    setState(() => _activeTab = index);
    _programmaticScroll = true;
    _centerActiveTabInBar(index);
    try {
      await _scrollCtrl.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } finally {
      // Give one frame for physics to settle before re-arming the
      // listener — Scroll physics can emit a tiny follow-up delta.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _programmaticScroll = false;
      });
    }
  }

  /// Cache of the last-known categories so the scroll listener can build
  /// the tab list without watching a provider (which would require ref
  /// access inside a listener callback).
  List<MenuCategory> _lastCategories = const [];

  List<_TabDef> _computeTabs(List<MenuCategory> cats) => [
        const _TabDef(id: 'featured', label: 'عروض مميزة'),
        const _TabDef(id: 'best-sellers', label: 'الأكثر مبيعاً'),
        const _TabDef(id: 'most-ordered', label: 'الأكثر طلباً'),
        for (final c in cats) _TabDef(id: 'cat-${c.id}', label: c.nameAr, categoryId: c.id),
      ];

  @override
  Widget build(BuildContext context) {
    final mediaTop = MediaQuery.of(context).padding.top;
    final cartLines = ref.watch(cartControllerProvider).lines.length;
    final hasCartBar = cartLines > 0;
    final catsAsync = ref.watch(categoriesProvider);
    final cats = catsAsync.maybeWhen(data: (list) => list, orElse: () => const <MenuCategory>[]);
    _lastCategories = cats;
    final tabs = _computeTabs(cats);

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
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // ------ Sticky glass header (pinned) ------
                // Kept inside the sliver list (not a Positioned overlay)
                // so the tab-bar sliver pins directly below it instead
                // of vanishing behind it.
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _GlassHeaderDelegate(height: mediaTop + _headerHeight),
                ),
                const SliverToBoxAdapter(child: _FulfillmentToggle()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const SliverToBoxAdapter(child: _HeroBanner()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                // ------ Sticky scrollspy tab bar (pinned) ------
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ScrollspyTabsDelegate(
                    height: _tabBarHeight,
                    tabs: tabs,
                    activeIndex: _activeTab,
                    tabBarScrollCtrl: _tabBarScrollCtrl,
                    tabKeyFor: _tabKey,
                    onTap: _scrollToSection,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                // ------ Sections, one per tab id, in tab order ------
                SliverToBoxAdapter(child: _FeaturedOffersSection(key: _sectionKey('featured'))),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _BestSellersSection(key: _sectionKey('best-sellers'))),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _MostOrderedList(key: _sectionKey('most-ordered'))),
                for (final c in cats) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: _CategorySection(
                      key: _sectionKey('cat-${c.id}'),
                      category: c,
                    ),
                  ),
                ],
                SliverToBoxAdapter(child: SizedBox(height: hasCartBar ? 260 : 140)),
              ],
            ),
          ),
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

/// Persistent-header delegate that pins the glass header at the top of
/// the CustomScrollView. The tab-bar sliver pins directly beneath it,
/// so the two stack cleanly (before this the header was a Positioned
/// overlay in the outer Stack, which covered whatever pinned sliver
/// tried to sit at scroll position 0).
class _GlassHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _GlassHeaderDelegate({required this.height});
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return const _StickyHeader();
  }
  @override
  bool shouldRebuild(covariant _GlassHeaderDelegate old) => old.height != height;
}

class _StickyHeader extends ConsumerWidget {
  const _StickyHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaTop = MediaQuery.of(context).padding.top;
    final session = ref.watch(authControllerProvider);
    final fulfillment = ref.watch(cartControllerProvider).fulfillment;

    // Address hierarchy — cart fulfillment beats saved default beats a
    // generic hint. Signed-in users always see one of their saved
    // addresses; guests see whatever they last typed at checkout, else
    // a "اختر عنواناً" prompt.
    final String label;
    if (fulfillment.address != null && fulfillment.address!.trim().isNotEmpty) {
      label = fulfillment.address!;
    } else if (session != null) {
      final defAsync = ref.watch(savedAddressesProvider);
      final def = defAsync.maybeWhen(
        data: (list) {
          if (list.isEmpty) return null;
          return list.firstWhere((a) => a.isDefault, orElse: () => list.first);
        },
        orElse: () => null,
      );
      label = def?.addressText ?? 'اختر عنواناً';
    } else {
      label = 'سجّل الدخول لاختيار عنوان';
    }

    // Rendered inside a SliverPersistentHeader delegate — so no
    // Positioned wrapper (no Stack ancestor). The delegate sets the
    // height to (mediaTop + 80); mediaTop is honoured by the
    // padding.only(top:) below so the row lands in the safe area.
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xE5FFF8F6),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1))],
      ),
      padding: EdgeInsets.only(top: mediaTop),
      child: SizedBox(
        height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openAddressPicker(context, ref, session),
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
                                label,
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
      );
  }

  Future<void> _openAddressPicker(BuildContext context, WidgetRef ref, dynamic session) async {
    if (session == null) {
      GoRouter.of(context).push('/login');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _AddressPickerSheet(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Address picker bottom sheet
// ═════════════════════════════════════════════════════════════════════

class _AddressPickerSheet extends ConsumerWidget {
  const _AddressPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedAddressesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.near_me, color: AppTheme.flameDeep, size: 20),
              const SizedBox(width: 8),
              Text('عنوان التوصيل', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text('اختر أحد عناوينك المحفوظة أو أضف عنواناً جديداً',
                style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: async.when(
                loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('تعذّر تحميل العناوين: $e', style: AppTheme.body(size: 12, color: AppTheme.pomegranateRed))),
                data: (list) {
                  if (list.isEmpty) return _EmptyAddressesInSheet();
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final a in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AddressPickerCard(address: a, onPicked: () => _pick(context, ref, a)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                GoRouter.of(context).push('/profile/addresses');
              },
              icon: const Icon(Icons.add_location_alt, size: 18, color: AppTheme.primary),
              label: Text('إدارة العناوين وإضافة عنوان جديد',
                  style: AppTheme.body(size: 13, weight: FontWeight.w700, color: AppTheme.primary)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: AppTheme.primaryContainer.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, SavedAddress a) async {
    // Two things happen atomically from the user's perspective:
    // 1) Server-side: mark this address as the default (PATCH) so the
    //    next login/session refresh reads it back.
    // 2) Client-side: seed the cart fulfillment so this order (and the
    //    header chip) reflect the choice immediately.
    final ful = ref.read(cartControllerProvider).fulfillment;
    ref.read(cartControllerProvider.notifier).setFulfillment(
          ful.type == FulfillmentType.pickup ? FulfillmentType.pickup : FulfillmentType.delivery,
          address: a.addressText,
        );
    Navigator.of(context).pop();
    try {
      await ref.read(authRepositoryProvider).setDefaultAddress(a.id);
      ref.invalidate(savedAddressesProvider);
    } catch (e) {
      // The client-side change already took effect; just note the sync failure.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('اختير العنوان لهذا الطلب — تعذّر تثبيته كافتراضي: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

class _AddressPickerCard extends StatelessWidget {
  const _AddressPickerCard({required this.address, required this.onPicked});
  final SavedAddress address;
  final VoidCallback onPicked;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPicked,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: address.isDefault ? AppTheme.primaryContainer.withValues(alpha: 0.05) : AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: address.isDefault ? AppTheme.primaryContainer.withValues(alpha: 0.4) : AppTheme.outlineVariant.withValues(alpha: 0.5),
            width: address.isDefault ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(10)),
              child: Icon(_iconForLabel(address.label), color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(address.label, style: AppTheme.headline(size: 14, weight: FontWeight.w700, color: AppTheme.onSurface))),
                    if (address.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.primaryContainer.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                        child: Text('افتراضي', style: AppTheme.body(size: 9, weight: FontWeight.w700, color: AppTheme.primary, letterSpacing: 0.4)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(address.addressText, style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted, height: 18 / 12)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_back_ios_new, size: 14, color: AppTheme.charcoalMuted),
          ],
        ),
      ),
    );
  }

  IconData _iconForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('منزل') || l.contains('بيت') || l.contains('home')) return Icons.home;
    if (l.contains('عمل') || l.contains('work') || l.contains('office')) return Icons.work_outline;
    return Icons.location_on;
  }
}

class _EmptyAddressesInSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.location_off, size: 48, color: AppTheme.charcoalMuted),
          const SizedBox(height: 12),
          Text('لا يوجد عناوين محفوظة بعد', style: AppTheme.headline(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('أضف أول عنوان لتظهر تلقائياً هنا في كل الطلبات القادمة.',
              textAlign: TextAlign.center, style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
        ],
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
                    'من على الفحم لباب بيتك 🔥',
                    style: AppTheme.headline(size: 22, weight: FontWeight.w700, color: AppTheme.surfaceBright, height: 30 / 22),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      'مشاوي طازجة ومتبّلة على الأصول، تصلك ساخنة في دقائق.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(size: 12, color: const Color(0xE6F7F3EE)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Active coupon chip — matches Stitch _1 "كود خصم: طلة20"
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCream,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.confirmation_number_outlined, size: 14, color: AppTheme.flameDeep),
                          const SizedBox(width: 4),
                          Text('كود خصم: طلة20',
                              style: AppTheme.body(size: 11, weight: FontWeight.w700, color: AppTheme.charcoalSoft)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.flameDeep, borderRadius: BorderRadius.circular(999)),
                            child: Text('20% خصم',
                                style: AppTheme.body(size: 9, weight: FontWeight.w800, color: AppTheme.surfaceBright, letterSpacing: 0.3)),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text('تطبق الشروط',
                          style: AppTheme.body(size: 10, weight: FontWeight.w600, color: const Color(0xCCFDFAF6))),
                    ],
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
// Scrollspy tab bar — SliverPersistentHeader (HungerStation-style)
// ═════════════════════════════════════════════════════════════════════

/// One tab definition — id keys both the section GlobalKey and the tab
/// GlobalKey (so the scrollspy can measure and center-scroll them).
class _TabDef {
  const _TabDef({required this.id, required this.label, this.categoryId});
  final String id;
  final String label;
  final int? categoryId; // populated for DB-category tabs; null for the
                         // three built-in sections (featured / best / most).
}

/// Pinned tab bar that tracks the currently-visible section and lets
/// the customer jump to any section by tapping its label. The whole bar
/// is horizontally scrollable so the tab list can grow arbitrarily as
/// new DB categories arrive.
class _ScrollspyTabsDelegate extends SliverPersistentHeaderDelegate {
  _ScrollspyTabsDelegate({
    required this.height,
    required this.tabs,
    required this.activeIndex,
    required this.tabBarScrollCtrl,
    required this.tabKeyFor,
    required this.onTap,
  });

  final double height;
  final List<_TabDef> tabs;
  final int activeIndex;
  final ScrollController tabBarScrollCtrl;
  final GlobalKey Function(String id) tabKeyFor;
  final void Function(int index) onTap;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xF2FFF8F6),
      alignment: Alignment.center,
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Trailing hairline so the bar reads as its own row when
            // welded to the top of the viewport.
            Expanded(
              child: ListView.separated(
                controller: tabBarScrollCtrl,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 20),
                itemBuilder: (context, i) {
                  final t = tabs[i];
                  final active = i == activeIndex;
                  return _ScrollspyTab(
                    key: tabKeyFor(t.id),
                    label: t.label,
                    active: active,
                    onTap: () => onTap(i),
                  );
                },
              ),
            ),
            Container(height: 1, color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ScrollspyTabsDelegate old) {
    return old.activeIndex != activeIndex ||
        old.tabs.length != tabs.length ||
        // Cheap check: label of first + last tab covers the common re-order
        (tabs.isNotEmpty &&
            (old.tabs.isEmpty ||
                old.tabs.first.id != tabs.first.id ||
                old.tabs.last.id != tabs.last.id));
  }
}

class _ScrollspyTab extends StatelessWidget {
  const _ScrollspyTab({super.key, required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              style: AppTheme.body(
                size: 13,
                weight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppTheme.onSurface : AppTheme.charcoalMuted,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Active indicator — thin charcoal underline flush to the
          // bottom of the bar (Stitch _1 + HungerStation reference).
          Container(
            height: 3,
            width: active ? 28 : 0,
            decoration: BoxDecoration(
              color: AppTheme.onSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Per-category section — one per DB category, appears in the same
// vertical scroll under the shared tab bar. Items load lazily on first
// build (each Sliver instantiates once and stays alive).
// ═════════════════════════════════════════════════════════════════════

class _CategorySection extends ConsumerWidget {
  const _CategorySection({super.key, required this.category});
  final MenuCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryItemsProvider(category.id));
    return async.when(
      loading: () => _SectionSkeleton(title: category.nameAr),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(children: [
                Container(width: 3, height: 20, decoration: BoxDecoration(
                  color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(category.nameAr, style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text('(${items.length})', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
              ]),
            ),
            const SizedBox(height: 12),
            ...items.map((it) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _DishTile(item: it),
                )),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// عروض مميزة — horizontal cards, one per active offer
// ═════════════════════════════════════════════════════════════════════

class _FeaturedOffersSection extends ConsumerWidget {
  const _FeaturedOffersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(offersProvider);
    return async.when(
      loading: () => const _SectionSkeleton(title: 'عروض مميزة 🔥'),
      error: (_, __) => const SizedBox.shrink(),
      data: (offers) {
        if (offers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: 'عروض مميزة 🔥', onSeeAll: () {}),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: offers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _FeaturedOfferCard(offer: offers[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FeaturedOfferCard extends ConsumerWidget {
  const _FeaturedOfferCard({required this.offer});
  final Offer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 280,
      child: InkWell(
        onTap: offer.linkedItemId != null
            ? () => ProductSheet.show(context, offer.linkedItemId!)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x0F1F1B19), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Image with discount badge + "add to cart" fab ----
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: FoodImage(url: offer.imageUrl, icon: Icons.local_fire_department, iconSize: 48),
                    ),
                  ),
                  // Discount badge — brand-red pill top-right
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.pomegranateRed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        offer.titleAr.contains('%')
                            ? '${offer.titleAr.split('%').first}% خصم'
                            : 'عرض خصم',
                        style: AppTheme.body(size: 10, weight: FontWeight.w800, color: AppTheme.surfaceBright, letterSpacing: 0.3),
                      ),
                    ),
                  ),
                  // Add-to-cart FAB — bottom-left of image (RTL: bottom-left is trailing)
                  if (offer.linkedItemId != null)
                    Positioned(
                      bottom: 8, left: 8,
                      child: SizedBox(
                        width: 40, height: 40,
                        child: Material(
                          color: AppTheme.primaryContainer,
                          shape: const CircleBorder(),
                          elevation: 4,
                          shadowColor: const Color(0x59E87722),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => ProductSheet.show(context, offer.linkedItemId!),
                            child: const Icon(Icons.add, color: AppTheme.onPrimary, size: 22),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // ---- Text block ----
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.titleAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.headline(size: 15, weight: FontWeight.w700, color: AppTheme.onSurface),
                    ),
                    if (offer.descriptionAr != null && offer.descriptionAr!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        offer.descriptionAr!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(size: 11, color: AppTheme.charcoalMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// الأكثر مبيعاً — horizontal item cards (first slice of mostOrdered)
// ═════════════════════════════════════════════════════════════════════

class _BestSellersSection extends ConsumerWidget {
  const _BestSellersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mostOrderedProvider);
    return async.when(
      loading: () => const _SectionSkeleton(title: 'الأكثر مبيعاً 🔥'),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final slice = items.take(4).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: 'الأكثر مبيعاً 🔥', onSeeAll: () {}),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: slice.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _BestSellerCard(item: slice[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BestSellerCard extends ConsumerWidget {
  const _BestSellerCard({required this.item});
  final ItemSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 200,
      child: InkWell(
        onTap: () => ProductSheet.show(context, item.id),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x0F1F1B19), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 16 / 11,
                    child: FoodImage(url: item.imageUrl, icon: Icons.local_fire_department, iconSize: 40),
                  ),
                ),
                Positioned(
                  bottom: 8, left: 8,
                  child: SizedBox(
                    width: 36, height: 36,
                    child: Material(
                      color: AppTheme.primaryContainer,
                      shape: const CircleBorder(),
                      elevation: 4,
                      shadowColor: const Color(0x59E87722),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => ProductSheet.show(context, item.id),
                        child: const Icon(Icons.add, color: AppTheme.onPrimary, size: 20),
                      ),
                    ),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nameAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.headline(size: 13, weight: FontWeight.w700, color: AppTheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.timer, size: 12, color: AppTheme.charcoalMuted),
                      const SizedBox(width: 4),
                      Text('20 دقيقة', style: AppTheme.body(size: 10, color: AppTheme.charcoalMuted)),
                    ]),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          (item.priceIsVariable && item.displayPriceFrom != null
                                  ? item.displayPriceFrom!
                                  : item.basePrice)
                              .toStringAsFixed(0),
                          style: AppTheme.priceTag(color: AppTheme.flameDeep, size: 16),
                        ),
                        const SizedBox(width: 4),
                        Text('ر.س', style: AppTheme.body(size: 10, color: AppTheme.charcoalMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Section header (title + عرض الكل)
// ═════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('عرض الكل', style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.flameDeep)),
                const Icon(Icons.chevron_left, size: 16, color: AppTheme.flameDeep),
              ]),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Most-ordered vertical list
// ═════════════════════════════════════════════════════════════════════

/// Vertical dish list — the "long tail" of most-ordered items after
/// [_BestSellersSection] has taken the first four for its horizontal card
/// strip. Skipping ensures nothing appears twice on the same page.
class _MostOrderedList extends ConsumerWidget {
  const _MostOrderedList({super.key});

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
        // Best-sellers strip already consumed the top 4; use the rest here.
        final rest = items.length > 4 ? items.skip(4).toList() : items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.local_fire_department, size: 20, color: AppTheme.flameDeep),
                    const SizedBox(width: 4),
                    Text('الأكثر طلباً 🔥', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
                  ]),
                  Text('خيارات سريعة ومميزة',
                      style: AppTheme.body(size: 10, weight: FontWeight.w600, color: AppTheme.charcoalMuted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...rest.take(8).map((it) => Padding(
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
      onTap: () => ProductSheet.show(context, item.id),
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
                ProductSheet.show(context, item.id);
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
