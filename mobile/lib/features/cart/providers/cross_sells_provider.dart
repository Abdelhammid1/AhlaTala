import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/item.dart';
import '../../../data/repositories/menu_repository.dart';

/// Cross-sell recommendations for a specific item id (US2.4).
final crossSellsProvider =
    FutureProvider.family<List<ItemSummary>, int>((ref, itemId) async {
  return ref.watch(menuRepositoryProvider).fetchCrossSells(itemId);
});
