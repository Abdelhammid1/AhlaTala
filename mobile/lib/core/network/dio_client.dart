import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../config/prefs.dart';

const kSessionKey = 'auth.session.v1'; // shared with AuthController

/// Shared Dio instance, configured from Env.apiBaseUrl.
///
/// The Authorization header is read from the SAME SharedPreferences instance
/// the AuthController writes to (via `sharedPrefsProvider`, resolved once in
/// main()). No `getInstance()` fetches inside the interceptor — that used to
/// return a stale copy on Android emulator right after the login write.
final dioProvider = Provider<Dio>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);

  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final raw = prefs.getString(kSessionKey);
      if (raw != null && raw.isNotEmpty) {
        // Pull the token out — JWT never contains a quote, so a plain
        // "token":"..." slice is safe.
        final start = raw.indexOf('"token":"');
        if (start >= 0) {
          final end = raw.indexOf('"', start + 9);
          if (end > start) {
            final token = raw.substring(start + 9, end);
            options.headers['Authorization'] = 'Bearer $token';
            if (kDebugMode) {
              debugPrint('[dio] Bearer attached (len=${token.length}) → ${options.uri}');
            }
          }
        }
      } else if (kDebugMode) {
        debugPrint('[dio] no session in prefs → anonymous ${options.uri}');
      }
      handler.next(options);
    },
  ));

  dio.interceptors.add(LogInterceptor(
    request: false,
    requestHeader: false,
    responseHeader: false,
    responseBody: false,
    error: true,
  ));

  return dio;
});
