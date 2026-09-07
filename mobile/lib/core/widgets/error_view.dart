import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Friendly full-screen error state for AsyncValue.error branches.
///
/// Never shows the raw exception text (`DioException [connection timeout]…`)
/// to customers — swaps it for a short Arabic hint keyed off the exception
/// type, plus a big "أعد المحاولة" button that calls [onRetry].
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, hint) = _classify(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('أعد المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  /// (icon, title, hint) — always Arabic, always short, never the raw
  /// exception text. Falls back to a generic "شيء ما لم يعمل" message.
  static (IconData, String, String) _classify(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return (
            Icons.wifi_off,
            'الاتصال بطيء',
            'تأكد من اتصالك بالإنترنت ثم أعد المحاولة.',
          );
        case DioExceptionType.connectionError:
          return (
            Icons.cloud_off,
            'تعذّر الاتصال بالخادم',
            'قد يكون الاتصال ضعيفاً أو الخادم غير متاح مؤقتاً.',
          );
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 0;
          if (code >= 500) {
            return (
              Icons.error_outline,
              'خطأ مؤقت في الخادم',
              'نعمل على إصلاحه — أعد المحاولة بعد لحظات.',
            );
          }
          return (
            Icons.info_outline,
            'حدث خطأ',
            'أعد المحاولة أو تواصل مع الدعم إذا استمرت المشكلة.',
          );
        case DioExceptionType.cancel:
          return (Icons.refresh, 'أُلغي الطلب', 'أعد المحاولة.');
        case DioExceptionType.badCertificate:
        case DioExceptionType.unknown:
        // ignore: deprecated_member_use
        default: // catches DioExceptionType.transformTimeout and future values
          return (
            Icons.wifi_off,
            'مشكلة في الاتصال',
            'تحقق من الإنترنت وأعد المحاولة.',
          );
      }
    }
    return (
      Icons.error_outline,
      'شيء ما لم يعمل',
      'أعد المحاولة أو تواصل مع الدعم إذا استمرت المشكلة.',
    );
  }
}
