import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../models/item.dart';
import '../models/offer.dart';

/// One-stop repository for the E7 home-screen data (offers + most-ordered).
class PromoRepository {
  PromoRepository(this._dio);
  final Dio _dio;

  Future<List<Offer>> fetchOffers() async {
    final res = await _dio.get<List<dynamic>>('/api/v1/offers');
    return (res.data ?? const [])
        .map((e) => Offer.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<ItemSummary>> fetchMostOrdered({int limit = 8}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/most-ordered',
      queryParameters: {'limit': limit},
    );
    return (res.data ?? const [])
        .map((e) => ItemSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final promoRepositoryProvider = Provider<PromoRepository>((ref) {
  return PromoRepository(ref.watch(dioProvider));
});
