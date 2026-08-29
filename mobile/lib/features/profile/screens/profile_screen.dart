import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/session.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/controllers/auth_controller.dart';

final _addressesProvider = FutureProvider.autoDispose<List<SavedAddress>>((ref) async {
  return ref.watch(authRepositoryProvider).addresses();
});

/// US9.4 — profile: editable name, phone (read-only), saved addresses list + CRUD.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    if (session == null) {
      // Don't redirect — show a friendly sign-in prompt inline. This avoids any
      // race where a brief null on rebuild would kick a signed-in user out to
      // /login (older behaviour). If prefs really are empty, the user picks
      // "تسجيل الدخول" and goes to /login on their own.
      return Scaffold(
        appBar: AppBar(
          title: const Text('ملفي'),
          leading: IconButton(
            tooltip: 'الرئيسية',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_circle_outlined, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('أنت غير مسجّل الدخول',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('سجّل دخولك بجوالك للوصول إلى ملفك وطلباتك السابقة.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('تسجيل الدخول'),
                  onPressed: () => context.push('/login'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('العودة للرئيسية'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفي'),
        leading: IconButton(
          tooltip: 'الرئيسية',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final router = GoRouter.of(context);
              await ref.read(authControllerProvider.notifier).logout();
              router.go('/');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _IdentityCard(customer: session.customer),
          const SizedBox(height: 12),
          _shortcut(context, Icons.receipt_long_outlined, 'طلباتي السابقة', '/profile/orders'),
          _shortcut(context, Icons.stars_outlined, 'نقاطي', '/loyalty'),
          _shortcut(context, Icons.notifications_outlined, 'الإشعارات', '/notifications'),
          const SizedBox(height: 12),
          _addressesSection(context, ref),
        ],
      ),
    );
  }

  Widget _shortcut(BuildContext context, IconData icon, String label, String route) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => context.push(route),
        ),
      );

  Widget _addressesSection(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_addressesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(children: [
            const Text('العناوين المحفوظة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('إضافة'),
              onPressed: () => _addAddressSheet(context, ref),
            ),
          ]),
        ),
        async.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Text('خطأ: $e')),
          data: (list) {
            if (list.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('لا توجد عناوين محفوظة بعد')),
                ),
              );
            }
            return Column(children: [
              for (final a in list)
                Card(
                  child: ListTile(
                    leading: Icon(a.isDefault ? Icons.home_rounded : Icons.location_on_outlined),
                    title: Row(children: [
                      Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (a.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                          child: Text('افتراضي', style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                        ),
                      ],
                    ]),
                    subtitle: Text(a.addressText),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).deleteAddress(a.id);
                        ref.invalidate(_addressesProvider);
                      },
                    ),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }

  Future<void> _addAddressSheet(BuildContext context, WidgetRef ref) async {
    final labelCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    bool isDefault = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('عنوان جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'التسمية (مثلاً: المنزل)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
              ),
              CheckboxListTile(
                value: isDefault,
                onChanged: (v) => setSt(() => isDefault = v ?? false),
                title: const Text('اجعله العنوان الافتراضي'),
                contentPadding: EdgeInsets.zero,
              ),
              FilledButton(
                onPressed: () async {
                  if (labelCtrl.text.trim().isEmpty || textCtrl.text.trim().isEmpty) return;
                  await ref.read(authRepositoryProvider).createAddress(
                        label: labelCtrl.text.trim(),
                        text: textCtrl.text.trim(),
                        isDefault: isDefault,
                      );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  ref.invalidate(_addressesProvider);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends ConsumerStatefulWidget {
  const _IdentityCard({required this.customer});
  final SessionCustomer customer;

  @override
  ConsumerState<_IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends ConsumerState<_IdentityCard> {
  late final _nameCtrl = TextEditingController(text: widget.customer.name ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final updated = await ref.read(authRepositoryProvider).patchName(_nameCtrl.text.trim());
    await ref.read(authControllerProvider.notifier).updateCustomer(updated);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الاسم')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  (widget.customer.name?.characters.firstOrNull ?? 'ع').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.customer.phone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${widget.customer.pointsBalance} نقطة',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              )),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonal(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ الاسم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
