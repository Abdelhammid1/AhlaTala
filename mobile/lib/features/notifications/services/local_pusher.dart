import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications so the rest of the app
/// doesn't have to know about channels / platform-specific details.
///
/// E8 uses this to fire an OS-level notification whenever the inbox unread
/// count grows while the app is running. Fully-out-of-process push (when the
/// app is killed) needs FCM — deferred with the FcmSender seam on the backend.
class LocalPusher {
  LocalPusher._();
  static final LocalPusher instance = LocalPusher._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialised = true;
  }

  Future<void> show({required int id, required String title, required String body}) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ahla_tolla_inbox',
        'أحلى طلة',
        channelDescription: 'إشعارات من مطعم أحلى طلة',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (_) {
      // Some platforms (web / desktop) don't support local notifications.
      // Silently swallow — the in-app inbox is the reliable path.
    }
  }
}
