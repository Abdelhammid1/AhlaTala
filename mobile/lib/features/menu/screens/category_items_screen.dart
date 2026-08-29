import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../cart/widgets/cart_badge.dart';
import '../providers/menu_providers.dart';
import '../widgets/item_card.dart';

class CategoryItemsScreen extends ConsumerWidget {
  const CategoryItemsScreen({super.key, required this.categoryId, this.title});
  final int categoryId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryItemsProvider(categoryId));
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'أصناف الفئة'),
        actions: const [CartBadge()],
      ),
      body: async.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد أصناف في هذه الفئة'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(categoryItemsProvider(categoryId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final it = items[i];
                return ItemCard(
                  item: it,
                  onTap: () => context.push('/items/${it.id}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}
