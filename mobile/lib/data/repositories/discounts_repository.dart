import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../models/discount.dart';

/// Preview result OR the server-provided (slug, message) pair for display.
class DiscountApplyResult {
  final DiscountPreview? preview;
  final String? errorSlug;
  final String? errorMessage;

  const DiscountApplyResult.ok(DiscountPreview p)
      : preview = p,
        errorSlug = null,
        errorMessage = null;

  const DiscountApplyResult.err(String slug, String message)
      : preview = null,
        errorSlug = slug,
        errorMessage = message;

  bool get ok => preview != null;
}

class DiscountsRepository {
  DiscountsRepository(this._dio);
  final Dio _dio;

  /// `pointsDiscount` is the money value of the loyalty redemption the customer
  /// has ALREADY previewed — passed so the server can validate the code against
  /// the correct post-points subtotal.
  Future<DiscountApplyResult> preview({
    required String code,
    required double subtotal,
    double pointsDiscount = 0,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/discount-codes/preview',
        data: {
          'code': code,
          'subtotal': subtotal.toStringAsFixed(2),
          'points_discount': pointsDiscount.toStringAsFixed(2),
        },
      );
      return DiscountApplyResult.ok(DiscountPreview.fromJson(res.data!));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && (e.response?.statusCode == 422)) {
        return DiscountApplyResult.err(
          (data['error'] as String?) ?? 'unknown',
          (data['message'] as String?) ?? 'تعذر تطبيق الكود',
        );
      }
      return const DiscountApplyResult.err('network', 'تعذر الاتصال بالخادم');
    }
  }
}

final discountsRepositoryProvider = Provider<DiscountsRepository>((ref) {
  return DiscountsRepository(ref.watch(dioProvider));
});
