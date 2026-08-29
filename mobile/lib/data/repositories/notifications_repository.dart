import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../models/notification.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<List<InboxItem>> list(int customerId) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/customers/$customerId/notifications',
    );
    return (res.data ?? const [])
        .map((e) => InboxItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> markRead(int customerId, int deliveryId) async {
    await _dio.post(
      '/api/v1/customers/$customerId/notifications/$deliveryId/read',
    );
  }

  /// Best-effort — for the future FCM plumbing. Silently ignores network errors
  /// so a missing backend doesn't derail the mobile side.
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? phone,
    int? customerId,
  }) async {
    try {
      await _dio.post('/api/v1/devices/register', data: {
        'token': token,
        'platform': platform,
        if (phone != null) 'phone': phone,
        if (customerId != null) 'customer_id': customerId,
      });
    } catch (_) {}
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(dioProvider));
});
