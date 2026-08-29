import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../models/category.dart';
import '../models/item.dart';

/// Single point of access to the menu-side backend endpoints.
class MenuRepository {
  MenuRepository(this._dio);
  final Dio _dio;

  Future<List<MenuCategory>> fetchCategories() async {
    final res = await _dio.get<List<dynamic>>('/api/v1/categories');
    final data = res.data ?? const [];
    return data
        .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<ItemSummary>> fetchItemsInCategory(int categoryId) async {
    final res = await _dio.get<List<dynamic>>('/api/v1/categories/$categoryId/items');
    final data = res.data ?? const [];
    return data
        .map((e) => ItemSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ItemDetail> fetchItem(int itemId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/v1/items/$itemId');
    return ItemDetail.fromJson(res.data!);
  }

  /// E2 (US2.4). Returns the items the admin linked as recommendations for
  /// [itemId], in the admin-chosen sort order.
  Future<List<ItemSummary>> fetchCrossSells(int itemId) async {
    final res = await _dio.get<List<dynamic>>('/api/v1/items/$itemId/cross_sells');
    final data = res.data ?? const [];
    return data
        .map((e) => ItemSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(dioProvider));
});
