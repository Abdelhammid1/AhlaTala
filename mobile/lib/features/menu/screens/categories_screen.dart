import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/brand_logo.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../cart/widgets/cart_badge.dart';
import '../../home/providers/promo_providers.dart';
import '../../home/widgets/most_ordered_tile.dart';
import '../../home/widgets/offer_card.dart';
import '../../notifications/widgets/notifications_bell.dart';
import '../providers/menu_providers.dart';
import '../widgets/category_tile.dart';

/// Home screen — three vertically stacked sections:
///   1) Offers carousel  (E7 US7.2, hidden when no active offers)
///   2) الأكثر طلبًا      (E7 US7.3, hidden when no delivered orders yet)
///   3) الفئات            (E1 US1.1)
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandLogoChip(height: 40),
        centerTitle: true,
        actions: [
          const NotificationsBell(),
          // Always route through /profile. ProfileScreen handles both the
          // signed-in and signed-out states, so we never yank the user to
          // login based on a possibly-stale isAuthedProvider read.
          Consumer(builder: (context, ref, _) {
            final authed = ref.watch(isAuthedProvider);
            return IconButton(
              tooltip: authed ? 'ملفي' : 'تسجيل الدخول',
              icon: Icon(authed ? Icons.person : Icons.person_outline),
              onPressed: () => context.push('/profile'),
            );
          }),
          const CartBadge(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(offersProvider);
          ref.invalidate(mostOrderedProvider);
          ref.invalidate(categoriesProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            _OffersSection(),
            _MostOrderedSection(),
            _SectionTitle('الفئات'),
            _CategoriesGrid(),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ---------- offers carousel (US7.2) ----------

class _OffersSection extends ConsumerWidget {
  const _OffersSection();

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
            const _SectionTitle('العروض الحالية'),
            SizedBox(
              height: 160,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.9),
                padEnds: false,
                itemCount: offers.length,
                itemBuilder: (_, i) => OfferCard(offer: offers[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------- most-ordered (US7.3) ----------

class _MostOrderedSection extends ConsumerWidget {
  const _MostOrderedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mostOrderedProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('الأكثر طلبًا'),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => MostOrderedTile(item: items[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------- categories grid (US1.1, unchanged) ----------

class _CategoriesGrid extends ConsumerWidget {
  const _CategoriesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);
    return async.when(
      data: (cats) {
        if (cats.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('لا توجد فئات متاحة حالياً')),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: cats.length,
          itemBuilder: (_, i) {
            final c = cats[i];
            return CategoryTile(
              category: c,
              onTap: () => context.push('/categories/${c.id}', extra: c.nameAr),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text('خطأ: $e')),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}
