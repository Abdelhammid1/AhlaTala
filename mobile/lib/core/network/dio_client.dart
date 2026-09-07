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

  // Timeouts sized for Saudi 4G/LTE in weak reception (VoLTE handshake +
  // TLS + TCP over a saturated cell can easily take 15-20s before any bytes
  // move). Wi-Fi still resolves in <1s so happy-path latency is unchanged.
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
  ));

  // Retry once (2s), twice (5s) on transient network failures — connection
  // timeout / send timeout / DNS failure / 502/503/504 from the reverse
  // proxy. Not on 4xx (those are real client errors that won't self-heal).
  dio.interceptors.add(InterceptorsWrapper(
    onError: (err, handler) async {
      final code = err.type;
      final status = err.response?.statusCode;
      final transient = code == DioExceptionType.connectionTimeout ||
          code == DioExceptionType.sendTimeout ||
          code == DioExceptionType.receiveTimeout ||
          code == DioExceptionType.connectionError ||
          (status != null && status >= 502 && status <= 504);
      final attempt = (err.requestOptions.extra['retry_attempt'] as int?) ?? 0;
      if (transient && attempt < 2) {
        final delay = Duration(seconds: attempt == 0 ? 2 : 5);
        await Future.delayed(delay);
        final opts = err.requestOptions
          ..extra['retry_attempt'] = attempt + 1;
        try {
          final res = await dio.fetch(opts);
          return handler.resolve(res);
        } catch (retryErr) {
          return handler.next(retryErr is DioException ? retryErr : err);
        }
      }
      handler.next(err);
    },
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
