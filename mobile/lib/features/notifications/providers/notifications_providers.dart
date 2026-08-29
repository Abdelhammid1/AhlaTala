import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/prefs.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/notification.dart';
import '../../../data/repositories/customers_repository.dart';
import '../../../data/repositories/notifications_repository.dart';

const _kSavedPhoneKey = 'notifications.saved_phone.v1';

/// Phone we remember once so the inbox + loyalty screens auto-populate.
/// Set from `LoyaltyScreen` on a successful lookup and from
/// `CheckoutController.submit` when an order is placed. E9 will replace
/// this with an authenticated `currentUser`.
class SavedPhoneNotifier extends StateNotifier<String?> {
  SavedPhoneNotifier(this._prefs) : super(_prefs.getString(_kSavedPhoneKey));
  final SharedPreferences _prefs;

  void save(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == state) return;
    state = trimmed;
    _prefs.setString(_kSavedPhoneKey, trimmed);
  }

  void clear() {
    state = null;
    _prefs.remove(_kSavedPhoneKey);
  }
}

final savedPhoneProvider =
    StateNotifierProvider<SavedPhoneNotifier, String?>((ref) {
  // Synchronous read — sharedPrefsProvider is overridden with a resolved
  // instance in main() before runApp().
  return SavedPhoneNotifier(ref.watch(sharedPrefsProvider));
});

/// Resolve saved-phone → CustomerBalance (which we use to key the inbox).
final currentCustomerProvider =
    FutureProvider.autoDispose<CustomerBalance?>((ref) async {
  final phone = ref.watch(savedPhoneProvider);
  if (phone == null || phone.length < 4) return null;
  return ref.watch(customersRepositoryProvider).lookup(phone);
});

/// The inbox itself. Keyed by customer id so switching phones doesn't stall.
final inboxProvider =
    FutureProvider.autoDispose.family<List<InboxItem>, int>((ref, customerId) async {
  return ref.watch(notificationsRepositoryProvider).list(customerId);
});

/// Convenience — how many unread items the bell should show.
final unreadCountProvider = Provider.autoDispose<int>((ref) {
  final cust = ref.watch(currentCustomerProvider).maybeWhen(
        data: (c) => c,
        orElse: () => null,
      );
  if (cust == null) return 0;
  final inbox = ref.watch(inboxProvider(cust.customerId)).maybeWhen(
        data: (items) => items,
        orElse: () => const <InboxItem>[],
      );
  return inbox.where((i) => !i.isRead).length;
});
