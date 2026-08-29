import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/category.dart';
import '../../../data/models/item.dart';
import '../../../data/repositories/menu_repository.dart';

final categoriesProvider = FutureProvider<List<MenuCategory>>((ref) async {
  return ref.watch(menuRepositoryProvider).fetchCategories();
});

final categoryItemsProvider =
    FutureProvider.family<List<ItemSummary>, int>((ref, categoryId) async {
  return ref.watch(menuRepositoryProvider).fetchItemsInCategory(categoryId);
});

final itemDetailProvider =
    FutureProvider.family<ItemDetail, int>((ref, itemId) async {
  return ref.watch(menuRepositoryProvider).fetchItem(itemId);
});
