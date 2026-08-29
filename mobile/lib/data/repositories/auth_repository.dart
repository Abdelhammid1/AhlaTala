import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../models/order.dart';
import '../models/session.dart';

class AuthResult<T> {
  final T? value;
  final String? errorSlug;
  final String? errorMessage;
  const AuthResult.ok(T v) : value = v, errorSlug = null, errorMessage = null;
  const AuthResult.err(String slug, String msg)
      : value = null, errorSlug = slug, errorMessage = msg;
  bool get ok => value != null;
}

/// Result of `requestOtp` — carries the optional `dev_code` when the backend
/// is running in debug mode with the LoggingSender (no real SMS provisioned).
class OtpRequestResult {
  final String? devCode;
  const OtpRequestResult({this.devCode});
}

class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  Future<AuthResult<OtpRequestResult>> requestOtp(String phone) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/otp/request',
        data: {'phone': phone},
      );
      return AuthResult.ok(OtpRequestResult(
        devCode: res.data?['dev_code'] as String?,
      ));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        return AuthResult.err(
          (data['error'] as String?) ?? 'unknown',
          (data['message'] as String?) ?? 'تعذّر إرسال الكود',
        );
      }
      return const AuthResult.err('network', 'تعذّر الاتصال بالخادم');
    }
  }

  Future<AuthResult<Session>> verifyOtp(String phone, String code) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/otp/verify',
        data: {'phone': phone, 'code': code},
      );
      return AuthResult.ok(Session(
        token: res.data!['access_token'] as String,
        customer: SessionCustomer.fromJson(res.data!['customer'] as Map<String, dynamic>),
      ));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        return AuthResult.err(
          (data['error'] as String?) ?? 'unknown',
          (data['message'] as String?) ?? 'تعذّر التحقق من الكود',
        );
      }
      return const AuthResult.err('network', 'تعذّر الاتصال بالخادم');
    }
  }

  Future<SessionCustomer> me() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/v1/me');
    return SessionCustomer.fromJson(r.data!);
  }

  Future<SessionCustomer> patchName(String name) async {
    final r = await _dio.patch<Map<String, dynamic>>('/api/v1/me', data: {'name': name});
    return SessionCustomer.fromJson(r.data!);
  }

  Future<List<OrderResp>> myOrders() async {
    final r = await _dio.get<List<dynamic>>('/api/v1/me/orders');
    return (r.data ?? const []).map((e) => OrderResp.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SavedAddress>> addresses() async {
    final r = await _dio.get<List<dynamic>>('/api/v1/me/addresses');
    return (r.data ?? const []).map((e) => SavedAddress.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SavedAddress> createAddress({required String label, required String text, bool isDefault = false}) async {
    final r = await _dio.post<Map<String, dynamic>>('/api/v1/me/addresses',
        data: {'label': label, 'address_text': text, 'is_default': isDefault});
    return SavedAddress.fromJson(r.data!);
  }

  Future<void> deleteAddress(int id) async {
    await _dio.delete('/api/v1/me/addresses/$id');
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});
