import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/floating_cart_bar.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/stitch_bottom_nav.dart';
import '../../../data/models/category.dart';
import '../../../data/models/item.dart';
import '../../cart/providers/cart_controller.dart';
import '../../item_details/widgets/product_sheet.dart';
import '../providers/menu_providers.dart';

/// "القائمة" — Stitch _4 shape.
///
/// The screen splits into two panels side by side:
///   - **Main body** (right in RTL, visually most of the screen): search
///     bar on top, hero card for the currently-selected category, and a
///     2-column grid of that category's items.
///   - **Vertical category rail** (left in RTL): stacked icon-and-label
///     rows, one per category. Active category shows an orange leading
///     bar + tinted background.
///
/// Behaviour:
///   - First render selects the first category from `categoriesProvider`
///     so the grid is never blank.
///   - Search filters inside the current category (client-side, since
///     each category is small).
///   - Tapping any product opens the ProductSheet — identical to home.
///   - Floating cart bar + Stitch bottom nav are shared chrome.
class MenuBrowseScreen extends ConsumerStatefulWidget {
  const MenuBrowseScreen({super.key});

  @override
  ConsumerState<MenuBrowseScreen> createState() => _MenuBrowseScreenState();
}

class _MenuBrowseScreenState extends ConsumerState<MenuBrowseScreen> {
  final _searchCtrl = TextEditingController();
  int? _categoryFilter; // seeded on first data callback with the first cat id
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    final topPad = MediaQuery.of(context).padding.top;
    final cartLines = ref.watch(cartControllerProvider).lines.length;
    final hasCartBar = cartLines > 0;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoriesProvider);
              if (_categoryFilter != null) {
                ref.invalidate(categoryItemsProvider(_categoryFilter!));
              }
            },
            child: catsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: EdgeInsets.only(top: topPad + 32, left: 16, right: 16),
                child: ErrorView(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
              ),
              data: (cats) {
                if (cats.isEmpty) {
                  return const Center(child: Text('لا توجد فئات متاحة'));
                }
                _categoryFilter ??= cats.first.id;
                final activeCat = cats.firstWhere(
                  (c) => c.id == _categoryFilter,
                  orElse: () => cats.first,
                );
                return Padding(
                  padding: EdgeInsets.only(top: topPad),
                  child: Column(
                    children: [
                      _TopBar(),
                      _SearchRow(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                      // ----- Body: [ main content | vertical rail ] -----
                      Expanded(
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            // Main content — hero + grid
                            Expanded(
                              child: _CategoryContentPane(
                                category: activeCat,
                                query: _query,
                                bottomPad: hasCartBar ? 210 : 96,
                              ),
                            ),
                            // Right-side vertical rail (visually right in RTL)
                            SizedBox(
                              width: 96,
                              child: _CategoryRail(
                                cats: cats,
                                activeId: _categoryFilter!,
                                onPick: (id) => setState(() => _categoryFilter = id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasCartBar)
                  const Padding(padding: EdgeInsets.only(bottom: 8), child: FloatingCartBar()),
                const StitchBottomNav(active: StitchNavTab.menu),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════ Top bar (profile + title + bell + search icon) ═════════════════

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(color: AppTheme.primaryContainer, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: AppTheme.onPrimary, size: 20),
          ),
          const Spacer(),
          Text('Menu', style: AppTheme.headline(size: 22, weight: FontWeight.w700, color: AppTheme.onSurface)),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined, size: 22, color: AppTheme.charcoalSoft),
              Positioned(
                top: -2, right: -2,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppTheme.flameDeep, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          const Icon(Icons.search, size: 22, color: AppTheme.charcoalSoft),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune, size: 20, color: AppTheme.charcoalSoft),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: AppTheme.body(size: 13, color: AppTheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'ابحث عن طبق أو مشويات...',
                  hintStyle: AppTheme.body(size: 12, color: AppTheme.charcoalMuted),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.charcoalMuted, size: 18),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════ Category content pane ═════════════════

class _CategoryContentPane extends ConsumerWidget {
  const _CategoryContentPane({
    required this.category,
    required this.query,
    required this.bottomPad,
  });
  final MenuCategory category;
  final String query;
  final double bottomPad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(categoryItemsProvider(category.id));
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _CategoryHero(category: category, itemsAsync: itemsAsync)),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        itemsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorView(error: e, onRetry: () => ref.invalidate(categoryItemsProvider(category.id))),
            ),
          ),
          data: (items) {
            final filtered = _filterItems(items, query);
            if (filtered.isEmpty) return SliverToBoxAdapter(child: _NoMatch(query: query));
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _GridItemCard(item: filtered[i]),
                  childCount: filtered.length,
                ),
              ),
            );
          },
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
      ],
    );
  }
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({required this.category, required this.itemsAsync});
  final MenuCategory category;
  final AsyncValue<List<ItemSummary>> itemsAsync;
  @override
  Widget build(BuildContext context) {
    final count = itemsAsync.maybeWhen(data: (l) => l.length, orElse: () => null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [AppTheme.flameDeep, AppTheme.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x33E87722), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Text(category.nameAr,
                      style: AppTheme.headline(size: 18, weight: FontWeight.w700, color: AppTheme.surfaceBright)),
                  const SizedBox(width: 6),
                  const Text('🔥', style: TextStyle(fontSize: 16)),
                ]),
                const SizedBox(height: 4),
                Text('طازجة ومتبّلة على الأصول يومياً',
                    style: AppTheme.body(size: 11, weight: FontWeight.w600, color: const Color(0xE6FDFAF6))),
              ],
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBright.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count أصناف متوفرة',
                  style: AppTheme.body(size: 10, weight: FontWeight.w800, color: AppTheme.surfaceBright, letterSpacing: 0.3)),
            ),
        ]),
      ),
    );
  }
}

// ═════════════════ Right-side vertical category rail ═════════════════

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.cats, required this.activeId, required this.onPick});
  final List<MenuCategory> cats;
  final int activeId;
  final ValueChanged<int> onPick;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceCreamSubtle.withValues(alpha: 0.4),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final c = cats[i];
          final active = c.id == activeId;
          return InkWell(
            onTap: () => onPick(c.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(
                color: active ? AppTheme.surfaceContainerLowest : Colors.transparent,
                border: active
                    ? const Border(right: BorderSide(color: AppTheme.primaryContainer, width: 3))
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primaryFixed : AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconFor(c.nameAr),
                      size: 20,
                      color: active ? AppTheme.primary : AppTheme.charcoalMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.nameAr,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      size: 10,
                      weight: FontWeight.w700,
                      color: active ? AppTheme.primary : AppTheme.charcoalSoft,
                      height: 14 / 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('شاورما')) return Icons.rice_bowl_outlined;
    if (n.contains('مشوي') || n.contains('مشاوي')) return Icons.outdoor_grill_outlined;
    if (n.contains('برجر')) return Icons.lunch_dining_outlined;
    if (n.contains('سندويش') || n.contains('ساندوت')) return Icons.bakery_dining_outlined;
    if (n.contains('عصائر') || n.contains('عصير') || n.contains('مشروب')) return Icons.local_bar_outlined;
    if (n.contains('حلوي') || n.contains('حلا')) return Icons.cake_outlined;
    if (n.contains('توفير') || n.contains('عرض')) return Icons.percent;
    return Icons.restaurant_menu;
  }
}

// ═════════════════ Grid item card (2-col) ═════════════════

class _GridItemCard extends ConsumerWidget {
  const _GridItemCard({required this.item});
  final ItemSummary item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => ProductSheet.show(context, item.id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: FoodImage(url: item.imageUrl, icon: Icons.restaurant, iconSize: 34),
                ),
              ),
              Positioned(
                bottom: 6, left: 6,
                child: SizedBox(
                  width: 34, height: 34,
                  child: Material(
                    color: AppTheme.primaryContainer,
                    shape: const CircleBorder(),
                    elevation: 3,
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
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.nameAr,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(size: 13, weight: FontWeight.w700, color: AppTheme.onSurface, height: 16 / 13)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.timer, size: 11, color: AppTheme.charcoalMuted),
                    const SizedBox(width: 4),
                    Text('15-20 د', style: AppTheme.body(size: 10, color: AppTheme.charcoalMuted)),
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
                        style: AppTheme.priceTag(color: AppTheme.flameDeep, size: 14),
                      ),
                      const SizedBox(width: 2),
                      Text('ر.س', style: AppTheme.body(size: 9, color: AppTheme.charcoalMuted)),
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

// ═════════════════ Empty search state ═════════════════

List<ItemSummary> _filterItems(List<ItemSummary> items, String q) {
  if (q.isEmpty) return items;
  final lower = q.toLowerCase();
  return items.where((it) {
    return it.nameAr.contains(q) ||
        (it.nameEn?.toLowerCase().contains(lower) ?? false);
  }).toList();
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});
  final String query;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 48, color: AppTheme.charcoalMuted),
          const SizedBox(height: 8),
          Text('لا توجد نتائج', style: AppTheme.headline(size: 14, weight: FontWeight.w700)),
          if (query.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('"$query"', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
          ],
        ],
      ),
    );
  }
}
