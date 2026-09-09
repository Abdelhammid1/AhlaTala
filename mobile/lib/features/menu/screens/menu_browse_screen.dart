import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/floating_cart_bar.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/stitch_bottom_nav.dart';
import '../../../data/models/item.dart';
import '../../cart/providers/cart_controller.dart';
import '../providers/menu_providers.dart';

/// "القائمة" — flat searchable browse of the whole menu.
///
/// Sits behind the second bottom-nav tab and is deliberately different
/// from the home screen: home is curated (categories + most-ordered
/// + offers), this is exhaustive (every item, search-first, category
/// chip filter). Pulls all categories and their items in parallel;
/// filters + searches client-side because the payload is ~120 items
/// which is cheap to sort in memory and gives instant feedback.
class MenuBrowseScreen extends ConsumerStatefulWidget {
  const MenuBrowseScreen({super.key});

  @override
  ConsumerState<MenuBrowseScreen> createState() => _MenuBrowseScreenState();
}

class _MenuBrowseScreenState extends ConsumerState<MenuBrowseScreen> {
  final _searchCtrl = TextEditingController();
  int? _categoryFilter; // null = all categories
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
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: topPad + 8)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Text('القائمة', style: AppTheme.headline(size: 22, weight: FontWeight.w700, color: AppTheme.onSurface)),
                        const Spacer(),
                        catsAsync.when(
                          data: (cats) => Text('${cats.length} تصنيف', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: _SearchBar(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                ),
                catsAsync.when(
                  loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => SliverFillRemaining(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ErrorView(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
                    ),
                  ),
                  data: (cats) {
                    if (cats.isEmpty) return const SliverFillRemaining(child: Center(child: Text('لا توجد فئات متاحة')));
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: cats.length + 1,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                if (i == 0) {
                                  return _CategoryChip(
                                    label: 'الكل',
                                    selected: _categoryFilter == null,
                                    onTap: () => setState(() => _categoryFilter = null),
                                  );
                                }
                                final c = cats[i - 1];
                                return _CategoryChip(
                                  label: c.nameAr,
                                  selected: _categoryFilter == c.id,
                                  onTap: () => setState(() => _categoryFilter = c.id),
                                );
                              },
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        // Category-scoped view — one section, item grid.
                        if (_categoryFilter != null)
                          _CategoryItemsSlivers(categoryId: _categoryFilter!, query: _query)
                        // "All" view — one section per category, each with the top items.
                        else
                          _AllCategoriesSlivers(cats: cats, query: _query),
                        SliverToBoxAdapter(child: SizedBox(height: hasCartBar ? 210 : 96)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasCartBar) const Padding(padding: EdgeInsets.only(bottom: 8), child: FloatingCartBar()),
                const StitchBottomNav(active: StitchNavTab.menu),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════ Search bar ═════════════════

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 6, offset: Offset(0, 1))],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTheme.body(size: 14, color: AppTheme.onSurface),
        decoration: InputDecoration(
          hintText: 'ابحث عن صنف — شاورما، ريش، كوكتيل...',
          hintStyle: AppTheme.body(size: 13, color: AppTheme.charcoalMuted),
          prefixIcon: const Icon(Icons.search, color: AppTheme.charcoalMuted, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.charcoalMuted),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
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
        ),
        child: Text(
          label,
          style: AppTheme.body(size: 12, weight: FontWeight.w700, color: selected ? AppTheme.onPrimary : AppTheme.charcoalSoft),
        ),
      ),
    );
  }
}

// ═════════════════ Filtered category view ═════════════════

class _CategoryItemsSlivers extends ConsumerWidget {
  const _CategoryItemsSlivers({required this.categoryId, required this.query});
  final int categoryId;
  final String query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryItemsProvider(categoryId));
    return async.when(
      loading: () => const SliverPadding(padding: EdgeInsets.all(32), sliver: SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverToBoxAdapter(child: ErrorView(error: e, onRetry: () => ref.invalidate(categoryItemsProvider(categoryId))))),
      data: (items) {
        final filtered = _filterItems(items, query);
        if (filtered.isEmpty) return SliverToBoxAdapter(child: _NoMatch(query: query));
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ItemTile(item: filtered[i]),
          ),
        );
      },
    );
  }
}

// ═════════════════ All-categories aggregation view ═════════════════

class _AllCategoriesSlivers extends ConsumerWidget {
  const _AllCategoriesSlivers({required this.cats, required this.query});
  final List<dynamic> cats;
  final String query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final c = cats[index];
          final catId = c.id as int;
          final async = ref.watch(categoryItemsProvider(catId));
          return async.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) {
              final filtered = _filterItems(items, query);
              if (filtered.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(children: [
                        Container(width: 3, height: 20, decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text(c.nameAr, style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Text('(${filtered.length})', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
                      ]),
                    ),
                    for (final it in filtered)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _ItemTile(item: it),
                      ),
                  ],
                ),
              );
            },
          );
        },
        childCount: cats.length,
      ),
    );
  }
}

List<ItemSummary> _filterItems(List<ItemSummary> items, String q) {
  if (q.isEmpty) return items;
  final lower = q.toLowerCase();
  return items.where((it) {
    return it.nameAr.contains(q) ||
        (it.nameEn?.toLowerCase().contains(lower) ?? false);
  }).toList();
}

// ═════════════════ Item tile (same layout as home) ═════════════════

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item});
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
          boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80, height: 80,
                child: FoodImage(url: item.imageUrl, icon: Icons.restaurant, iconSize: 32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.nameAr, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.headline(size: 15, weight: FontWeight.w700, color: AppTheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(
                    item.priceIsVariable && item.displayPriceFrom != null
                        ? 'أحجام مختلفة'
                        : 'جاهز في 15-25 د',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        item.priceIsVariable && item.displayPriceFrom != null
                            ? item.displayPriceFrom!.toStringAsFixed(0)
                            : item.basePrice.toStringAsFixed(0),
                        style: AppTheme.priceTag(size: 16, color: AppTheme.flameDeep),
                      ),
                      const SizedBox(width: 4),
                      Text('ر.س', style: AppTheme.body(size: 10, color: AppTheme.charcoalMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_back_ios_new, size: 14, color: AppTheme.charcoalMuted),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});
  final String query;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 56, color: AppTheme.charcoalMuted),
          const SizedBox(height: 12),
          Text('لا توجد نتائج تطابق', style: AppTheme.headline(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('"$query"', style: AppTheme.body(size: 13, color: AppTheme.charcoalMuted)),
        ],
      ),
    );
  }
}
