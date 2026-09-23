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

  /// Create a saved address. Only [label] + [text] are required — every
  /// other parameter maps to a Stitch _3 field the backend will happily
  /// accept as null. When [labelType] is passed it must be one of
  /// `home` / `office` / `hotel` / `rest` / `other`; anything else is
  /// silently ignored server-side.
  Future<SavedAddress> createAddress({
    required String label,
    required String text,
    bool isDefault = false,
    String? labelType,
    String? districtName,
    String? aptNumber,
    String? floor,
    String? extraDetails,
    String? contactPhone,
    bool leaveAtDoor = false,
    bool dontRingBell = false,
    String? photoUrl,
    double? lat,
    double? lng,
    String? formattedAddress,
  }) async {
    final data = <String, dynamic>{
      'label': label,
      'address_text': text,
      'is_default': isDefault,
      if (labelType != null) 'label_type': labelType,
      if (districtName != null) 'district_name': districtName,
      if (aptNumber != null) 'apt_number': aptNumber,
      if (floor != null) 'floor': floor,
      if (extraDetails != null) 'extra_details': extraDetails,
      if (contactPhone != null) 'contact_phone': contactPhone,
      'leave_at_door': leaveAtDoor,
      'dont_ring_bell': dontRingBell,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (formattedAddress != null) 'formatted_address': formattedAddress,
    };
    final r = await _dio.post<Map<String, dynamic>>('/api/v1/me/addresses', data: data);
    return SavedAddress.fromJson(r.data!);
  }

  /// Update any subset of a saved address. Unspecified named args leave the
  /// server-side value alone (partial PATCH semantics). Pass empty strings
  /// to clear text fields.
  Future<SavedAddress> updateAddress(
    int id, {
    String? label,
    String? addressText,
    bool? isDefault,
    String? labelType,
    String? districtName,
    String? aptNumber,
    String? floor,
    String? extraDetails,
    String? contactPhone,
    bool? leaveAtDoor,
    bool? dontRingBell,
    String? photoUrl,
    double? lat,
    double? lng,
    String? formattedAddress,
  }) async {
    final data = <String, dynamic>{
      if (label != null) 'label': label,
      if (addressText != null) 'address_text': addressText,
      if (isDefault != null) 'is_default': isDefault,
      if (labelType != null) 'label_type': labelType,
      if (districtName != null) 'district_name': districtName,
      if (aptNumber != null) 'apt_number': aptNumber,
      if (floor != null) 'floor': floor,
      if (extraDetails != null) 'extra_details': extraDetails,
      if (contactPhone != null) 'contact_phone': contactPhone,
      if (leaveAtDoor != null) 'leave_at_door': leaveAtDoor,
      if (dontRingBell != null) 'dont_ring_bell': dontRingBell,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (formattedAddress != null) 'formatted_address': formattedAddress,
    };
    final r = await _dio.patch<Map<String, dynamic>>('/api/v1/me/addresses/$id', data: data);
    return SavedAddress.fromJson(r.data!);
  }

  Future<void> deleteAddress(int id) async {
    await _dio.delete('/api/v1/me/addresses/$id');
  }

  /// Permanently delete the caller's account.
  ///
  /// The server scrubs personal identifiers from historical orders
  /// (Saudi tax law requires the invoice records to survive) and
  /// destroys everything else — saved addresses, OTP codes, loyalty
  /// ledger, customer row. Returns void on 204. Callers MUST clear
  /// the local session immediately after this returns.
  Future<void> deleteAccount() async {
    await _dio.delete('/api/v1/me');
  }

  /// Mark one address as the default. The backend enforces
  /// "exactly one default" — passing `is_default: true` unsets every other
  /// address on the caller's account in a single transaction.
  Future<SavedAddress> setDefaultAddress(int id) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/me/addresses/$id',
      data: {'is_default': true},
    );
    return SavedAddress.fromJson(r.data!);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});
