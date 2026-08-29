import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/prefs.dart';
import '../../../core/network/dio_client.dart' show kSessionKey;
import '../../../data/models/session.dart';

/// Persisted session state. `null` means anonymous / guest.
class AuthController extends StateNotifier<Session?> {
  AuthController(this._prefs) : super(_restore(_prefs)) {
    if (kDebugMode) {
      debugPrint('[auth] AuthController spun up. hasSession=${state != null}'
          '${state != null ? " phone=${state!.customer.phone}" : ""}');
    }
  }
  final SharedPreferences _prefs;

  static Session? _restore(SharedPreferences prefs) {
    final raw = prefs.getString(kSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('[auth] _restore failed: $e — clearing bad blob');
      prefs.remove(kSessionKey);
      return null;
    }
  }

  Future<void> set(Session session) async {
    state = session;
    final encoded = jsonEncode(session.toJson());
    final ok = await _prefs.setString(kSessionKey, encoded);
    if (kDebugMode) {
      final verify = _prefs.getString(kSessionKey);
      debugPrint('[auth] set() — write ok=$ok, echoLen=${verify?.length}');
    }
  }

  Future<void> updateCustomer(SessionCustomer c) async {
    final current = state;
    if (current == null) return;
    final next = Session(token: current.token, customer: c);
    await set(next);
  }

  Future<void> logout() async {
    state = null;
    await _prefs.remove(kSessionKey);
    if (kDebugMode) debugPrint('[auth] logout — session cleared');
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, Session?>((ref) {
  // Synchronous read from the app-wide prefs provider — resolved in main().
  return AuthController(ref.watch(sharedPrefsProvider));
});

/// True when the user is signed in with a verified account.
final isAuthedProvider = Provider<bool>((ref) => ref.watch(authControllerProvider) != null);
