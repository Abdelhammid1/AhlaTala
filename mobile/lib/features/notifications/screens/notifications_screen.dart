import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/models/notification.dart';
import '../../../data/repositories/notifications_repository.dart';
import '../providers/notifications_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(savedPhoneProvider);
    if (phone == null) {
      return _promptForPhone(context);
    }
    final custAsync = ref.watch(currentCustomerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: custAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (c) {
          if (c == null) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('لم يتم العثور على حساب لهذا الرقم بعد. اطلب طلبك الأول لتبدأ.',
                  textAlign: TextAlign.center),
            ));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(inboxProvider(c.customerId)),
            child: _InboxList(customerId: c.customerId),
          );
        },
      ),
    );
  }

  Widget _promptForPhone(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('لم يتم ربط جوالك بعد',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('افتح شاشة "نقاطي" وأدخل رقم جوالك مرة واحدة، سنتذكرك لاحقاً.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/loyalty'),
                  child: const Text('اذهب إلى نقاطي'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _InboxList extends ConsumerWidget {
  const _InboxList({required this.customerId});
  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inboxProvider(customerId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (items) {
        if (items.isEmpty) {
          return _empty();
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _InboxTile(item: items[i], customerId: customerId),
        );
      },
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              const Text('لا يوجد إشعارات بعد'),
            ],
          ),
        ),
      );
}

class _InboxTile extends ConsumerWidget {
  const _InboxTile({required this.item, required this.customerId});
  final InboxItem item;
  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Pattern-only formatter — no locale data needed at runtime.
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: item.isRead ? Colors.white : theme.colorScheme.primary.withValues(alpha: 0.06),
      child: ListTile(
        leading: Icon(
          item.isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
          color: item.isRead ? Colors.grey.shade500 : theme.colorScheme.primary,
        ),
        title: Text(item.title,
            style: TextStyle(fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w800)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text(item.body, style: TextStyle(color: Colors.grey.shade800)),
            if (item.sentAt != null) ...[
              const SizedBox(height: 6),
              Text(fmt.format(item.sentAt!.toLocal()),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ],
        ),
        onTap: item.isRead
            ? null
            : () async {
                await ref
                    .read(notificationsRepositoryProvider)
                    .markRead(customerId, item.deliveryId);
                ref.invalidate(inboxProvider(customerId));
                // Also refresh the customer lookup so any dependent unread badges update.
                ref.invalidate(currentCustomerProvider);
              },
      ),
    );
  }
}
