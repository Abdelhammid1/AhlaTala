import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../models/customer.dart';

class CustomersRepository {
  CustomersRepository(this._dio);
  final Dio _dio;

  /// Returns null when the phone has no customer record yet (404).
  Future<CustomerBalance?> lookup(String phone) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/customers/lookup',
        queryParameters: {'phone': phone},
      );
      return CustomerBalance.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<LoyaltyLedgerEntry>> ledger(int customerId) async {
    final res = await _dio.get<List<dynamic>>('/api/v1/customers/$customerId/ledger');
    return (res.data ?? const [])
        .map((e) => LoyaltyLedgerEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(ref.watch(dioProvider));
});
