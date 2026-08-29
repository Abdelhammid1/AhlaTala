import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/prefs.dart';
import '../providers/notifications_providers.dart';
import 'local_pusher.dart';

const _kLastSeenDeliveryIdKey = 'notifications.last_seen_delivery_id.v1';

/// Polls the inbox provider every 20 seconds while the app is running.
/// When a delivery id greater than the last-seen baseline appears, fires a
/// local OS notification for it. Baseline is persisted so a restart doesn't
/// re-announce every message.
///
/// This is the closest we can get to real push without FCM: any moment the
/// app is foregrounded (or freshly resumed) after an admin broadcast, the
/// customer sees a native OS toast. E8's audit report documents the gap.
class InboxPoller {
  InboxPoller(this._ref, this._prefs);
  final Ref _ref;
  final SharedPreferences _prefs;

  Timer? _timer;
  int? _lastSeenId;
  int? _customerId;

  void start(int customerId) {
    if (_customerId == customerId && _timer != null) return;
    stop();
    _customerId = customerId;
    _lastSeenId = _prefs.getInt('$_kLastSeenDeliveryIdKey.$customerId');
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _customerId = null;
    _lastSeenId = null;
  }

  Future<void> _tick() async {
    final cid = _customerId;
    if (cid == null) return;
    try {
      _ref.invalidate(inboxProvider(cid));
      final items = await _ref.read(inboxProvider(cid).future);
      if (items.isEmpty) return;
      // Baseline handling: first tick after clean install records without
      // firing — otherwise every existing item would fire on startup.
      if (_lastSeenId == null) {
        _lastSeenId = items.first.deliveryId;
        await _prefs.setInt('$_kLastSeenDeliveryIdKey.$cid', _lastSeenId!);
        return;
      }
      final baseline = _lastSeenId!;
      final fresh = items.where((i) => i.deliveryId > baseline).toList()
        ..sort((a, b) => a.deliveryId.compareTo(b.deliveryId));
      for (final n in fresh) {
        await LocalPusher.instance.show(
          id: n.deliveryId,
          title: n.title,
          body: n.body,
        );
      }
      if (fresh.isNotEmpty) {
        _lastSeenId = fresh.last.deliveryId;
        await _prefs.setInt('$_kLastSeenDeliveryIdKey.$cid', _lastSeenId!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('InboxPoller tick failed: $e');
    }
  }
}

/// One poller per app session. Lifecycle is bound to the `currentCustomerProvider`;
/// see the observer widget in main.dart.
final inboxPollerProvider = Provider<InboxPoller?>((ref) {
  return InboxPoller(ref, ref.watch(sharedPrefsProvider));
});
