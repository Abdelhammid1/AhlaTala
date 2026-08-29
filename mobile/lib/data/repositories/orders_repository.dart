import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../models/order.dart';

/// Thin wrapper around the E3 orders API.
class OrdersRepository {
  OrdersRepository(this._dio);
  final Dio _dio;

  Future<OrderCreateResp> createOrder(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>('/api/v1/orders', data: body);
    return OrderCreateResp.fromJson(res.data!);
  }

  Future<OrderResp> fetchOrder(int orderId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/v1/orders/$orderId');
    return OrderResp.fromJson(res.data!);
  }

  Future<OrderResp> confirmOrder(int orderId, {String? reference}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/orders/$orderId/confirm',
      data: {'reference': reference},
    );
    return OrderResp.fromJson(res.data!);
  }

  Future<OrderResp> failOrder(int orderId) async {
    final res = await _dio.post<Map<String, dynamic>>('/api/v1/orders/$orderId/fail');
    return OrderResp.fromJson(res.data!);
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(dioProvider));
});
