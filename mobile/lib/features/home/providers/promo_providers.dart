import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/item.dart';
import '../../../data/models/offer.dart';
import '../../../data/repositories/promo_repository.dart';

final offersProvider = FutureProvider<List<Offer>>((ref) async {
  return ref.watch(promoRepositoryProvider).fetchOffers();
});

final mostOrderedProvider = FutureProvider<List<ItemSummary>>((ref) async {
  return ref.watch(promoRepositoryProvider).fetchMostOrdered(limit: 8);
});
