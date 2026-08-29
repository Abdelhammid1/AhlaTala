import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/customer.dart';
import '../../../data/repositories/customers_repository.dart';

/// Look up a customer by phone. Returns null when unknown (backend 404).
final customerBalanceProvider =
    FutureProvider.family.autoDispose<CustomerBalance?, String>((ref, phone) async {
  final trimmed = phone.trim();
  if (trimmed.length < 4) return null;
  return ref.watch(customersRepositoryProvider).lookup(trimmed);
});

final ledgerProvider =
    FutureProvider.family.autoDispose<List<LoyaltyLedgerEntry>, int>((ref, id) async {
  return ref.watch(customersRepositoryProvider).ledger(id);
});
