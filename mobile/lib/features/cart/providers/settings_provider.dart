import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// Server-side settings the mobile app cares about.
/// E2: delivery fee + currency. E5: loyalty rates.
class AppSettings {
  final double deliveryFee;
  final String currency;
  final double pointsPerRiyal;
  final double riyalPerPoint;
  final int minRedeemPoints;

  const AppSettings({
    required this.deliveryFee,
    required this.currency,
    required this.pointsPerRiyal,
    required this.riyalPerPoint,
    required this.minRedeemPoints,
  });

  factory AppSettings.fallback() => const AppSettings(
        deliveryFee: 15.0,
        currency: 'SAR',
        pointsPerRiyal: 1.0,
        riyalPerPoint: 0.10,
        minRedeemPoints: 100,
      );

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        deliveryFee: double.tryParse(j['delivery_fee']?.toString() ?? '') ?? 0.0,
        currency: (j['currency'] as String?) ?? 'SAR',
        pointsPerRiyal:
            double.tryParse(j['points_per_riyal']?.toString() ?? '') ?? 1.0,
        riyalPerPoint:
            double.tryParse(j['riyal_per_point']?.toString() ?? '') ?? 0.10,
        minRedeemPoints: (j['min_redeem_points'] as num?)?.toInt() ?? 100,
      );
}

final settingsProvider = FutureProvider<AppSettings>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/settings');
    return AppSettings.fromJson(res.data!);
  } catch (_) {
    // Never block the checkout flow on a settings call; fall back to a sensible
    // default and surface the failure via server logs / next retry.
    return AppSettings.fallback();
  }
});
