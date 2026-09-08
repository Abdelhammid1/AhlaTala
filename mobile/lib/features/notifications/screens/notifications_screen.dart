import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../data/models/notification.dart';
import '../../../data/repositories/notifications_repository.dart';
import '../providers/notifications_providers.dart';

/// Notifications + offers inbox — Stitch design.
///
/// The inbox is per-customer (E8). We resolve the current customer via
/// `currentCustomerProvider` (which reads the signed-in session first, else
/// the saved phone from a prior loyalty lookup). If neither is set, we
/// prompt the user to sign in or open the loyalty screen once.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(savedPhoneProvider);
    if (phone == null) return const _NoAccount();
    final custAsync = ref.watch(currentCustomerProvider);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: custAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorView(error: e, onRetry: () => ref.invalidate(currentCustomerProvider)),
                ),
                data: (c) {
                  if (c == null) return const _NoAccount();
                  return _InboxList(customerId: c.customerId);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44, height: 44,
            child: Material(
              color: AppTheme.surfaceContainer,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
                child: const Icon(Icons.arrow_forward, size: 20, color: AppTheme.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الإشعارات والعروض', style: AppTheme.headline(size: 20, weight: FontWeight.w700, color: AppTheme.onSurface)),
              Text('تنبيهات حالة الطلبات والحملات الترويجية', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InboxList extends ConsumerWidget {
  const _InboxList({required this.customerId});
  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inboxProvider(customerId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(inboxProvider(customerId)),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 40),
          Padding(padding: const EdgeInsets.all(16), child: ErrorView(error: e, onRetry: () => ref.invalidate(inboxProvider(customerId)))),
        ]),
        data: (items) {
          if (items.isEmpty) {
            return ListView(children: const [SizedBox(height: 80), _EmptyInbox()]);
          }
          final unread = items.where((i) => !i.isRead).toList();
          final read = items.where((i) => i.isRead).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              if (unread.isNotEmpty) ...[
                _SectionTitle('جديدة (${unread.length})'),
                for (final it in unread)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InboxCard(item: it, customerId: customerId),
                  ),
              ],
              if (read.isNotEmpty) ...[
                if (unread.isNotEmpty) const SizedBox(height: 12),
                _SectionTitle('سابقة'),
                for (final it in read)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InboxCard(item: it, customerId: customerId),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text, style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.charcoalMuted, letterSpacing: 0.6)),
      );
}

class _InboxCard extends ConsumerWidget {
  const _InboxCard({required this.item, required this.customerId});
  final InboxItem item;
  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final isPromo = item.title.contains('عرض') || item.body.contains('خصم') || item.body.contains('كود');
    final accent = isPromo ? AppTheme.amberVibrant : AppTheme.primary;
    return InkWell(
      onTap: item.isRead
          ? null
          : () async {
              await ref.read(notificationsRepositoryProvider).markRead(customerId, item.deliveryId);
              ref.invalidate(inboxProvider(customerId));
              ref.invalidate(currentCustomerProvider);
            },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? AppTheme.surfaceContainerLowest : accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: item.isRead ? null : Border.all(color: accent.withValues(alpha: 0.2)),
          boxShadow: item.isRead
              ? const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 6, offset: Offset(0, 1))]
              : const [BoxShadow(color: Color(0x141F1B19), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPromo ? Icons.local_offer : Icons.notifications_active,
                size: 22, color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTheme.headline(size: 15, weight: item.isRead ? FontWeight.w600 : FontWeight.w700, color: AppTheme.onSurface),
                      ),
                    ),
                    if (!item.isRead) ...[
                      const SizedBox(width: 6),
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(size: 13, color: AppTheme.onSurfaceVariant, height: 20 / 13),
                  ),
                  if (item.sentAt != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.access_time, size: 12, color: AppTheme.charcoalMuted),
                      const SizedBox(width: 4),
                      Text(fmt.format(item.sentAt!.toLocal()), style: AppTheme.body(size: 11, color: AppTheme.charcoalMuted)),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.mark_email_read, size: 44, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text('صندوق الوارد فارغ', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('ستصلك هنا تحديثات حالة الطلب والعروض الترويجية.',
              textAlign: TextAlign.center, style: AppTheme.body(size: 13, color: AppTheme.charcoalMuted)),
        ],
      ),
    );
  }
}

class _NoAccount extends StatelessWidget {
  const _NoAccount();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_off_outlined, size: 72, color: AppTheme.primaryContainer),
                const SizedBox(height: 12),
                Text('لم يتم ربط جوالك بعد', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('سجّل دخولك بالجوال لتصلك إشعارات حالة الطلب والعروض الترويجية.',
                    textAlign: TextAlign.center, style: AppTheme.body(size: 13, color: AppTheme.charcoalMuted)),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.push('/login'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryContainer, foregroundColor: AppTheme.onPrimary, minimumSize: const Size(220, 48)),
                  child: const Text('تسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
