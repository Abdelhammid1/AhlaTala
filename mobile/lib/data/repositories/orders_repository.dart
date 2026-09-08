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

  /// Submit a post-delivery rating. Requires a signed-in session (the JWT
  /// interceptor attaches Authorization automatically).
  ///
  /// Returns `RatingResult.ok` on success, `RatingResult.alreadyRated`
  /// when the server responds 409 (order already has a rating — which
  /// is not really an error for the user; the UI can jump to the success
  /// state anyway), and `RatingResult.failed(msg)` for everything else.
  Future<RatingResult> submitRating(
    int orderId, {
    required int rating,
    List<String> tags = const [],
    String? comment,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/me/orders/$orderId/rating',
        data: {
          'rating': rating,
          if (tags.isNotEmpty) 'tags': tags,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        },
      );
      return const RatingResult.ok();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 409) return const RatingResult.alreadyRated();
      final msg = e.response?.data is Map
          ? ((e.response!.data as Map)['message']?.toString() ?? 'تعذّر إرسال التقييم')
          : 'تعذّر إرسال التقييم';
      return RatingResult.failed(msg);
    }
  }
}

/// Tagged-union result for [OrdersRepository.submitRating].
sealed class RatingResult {
  const RatingResult();
  const factory RatingResult.ok() = RatingOk;
  const factory RatingResult.alreadyRated() = RatingAlreadyRated;
  const factory RatingResult.failed(String message) = RatingFailed;
}
class RatingOk extends RatingResult { const RatingOk(); }
class RatingAlreadyRated extends RatingResult { const RatingAlreadyRated(); }
class RatingFailed extends RatingResult {
  const RatingFailed(this.message);
  final String message;
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(dioProvider));
});
