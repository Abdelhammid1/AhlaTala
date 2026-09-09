import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../data/models/session.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/controllers/auth_controller.dart';

/// Public provider so profile shortcuts can invalidate it after edits.
final savedAddressesProvider = FutureProvider.autoDispose<List<SavedAddress>>((ref) async {
  return ref.watch(authRepositoryProvider).addresses();
});

/// "العناوين المحفوظة" — Stitch design as its own screen at
/// /profile/addresses. Real CRUD against /api/v1/me/addresses.
///
/// Set [autoOpenAddSheet] (via `?add=1` on the route) to have the
/// "add address" bottom sheet open automatically on first frame —
/// used by the post-login onboarding when the account has no addresses.
class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key, this.autoOpenAddSheet = false});
  final bool autoOpenAddSheet;

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoOpenAddSheet) {
      // Delay by one frame after the layout so the sheet animates in
      // over a fully-rendered screen, not the initial blank Scaffold.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _addAddressSheet(context, ref);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    if (session == null) {
      return const _LoggedOutState();
    }
    final async = ref.watch(savedAddressesProvider);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorView(error: e, onRetry: () => ref.invalidate(savedAddressesProvider)),
                ),
                data: (list) => RefreshIndicator(
                  onRefresh: () async => ref.invalidate(savedAddressesProvider),
                  child: list.isEmpty
                      ? _EmptyState(onAdd: () => _addAddressSheet(context, ref))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          children: [
                            for (final a in list) _AddressCard(address: a, onDelete: () async {
                              await ref.read(authRepositoryProvider).deleteAddress(a.id);
                              ref.invalidate(savedAddressesProvider);
                            }),
                            const SizedBox(height: 96),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAddressSheet(context, ref),
        backgroundColor: AppTheme.primaryContainer,
        foregroundColor: AppTheme.onPrimary,
        icon: const Icon(Icons.add_location_alt),
        label: Text('عنوان جديد', style: AppTheme.body(size: 14, weight: FontWeight.w700, color: AppTheme.onPrimary)),
      ),
    );
  }

  Future<void> _addAddressSheet(BuildContext context, WidgetRef ref) async {
    final labelCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    var isDefault = false;
    var busy = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('عنوان جديد', textAlign: TextAlign.center, style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('يستخدم لتوصيل طلباتك القادمة', textAlign: TextAlign.center, style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'التسمية (مثال: المنزل، العمل)', prefixIcon: Icon(Icons.label_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                minLines: 2, maxLines: 4,
                decoration: const InputDecoration(labelText: 'العنوان بالتفصيل', prefixIcon: Icon(Icons.pin_drop_outlined)),
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                value: isDefault,
                onChanged: (v) => setSt(() => isDefault = v ?? false),
                title: Text('اجعله العنوان الافتراضي', style: AppTheme.body(size: 14, weight: FontWeight.w600)),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.primaryContainer,
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (labelCtrl.text.trim().isEmpty || textCtrl.text.trim().isEmpty) return;
                        setSt(() => busy = true);
                        try {
                          await ref.read(authRepositoryProvider).createAddress(
                                label: labelCtrl.text.trim(),
                                text: textCtrl.text.trim(),
                                isDefault: isDefault,
                              );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          ref.invalidate(savedAddressesProvider);
                        } catch (e) {
                          setSt(() => busy = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('تعذّر الحفظ: $e')));
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: AppTheme.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary))
                    : const Text('حفظ العنوان'),
              ),
              const SizedBox(height: 8),
            ],
          ),
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
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_forward, size: 20, color: AppTheme.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('العناوين المحفوظة', style: AppTheme.headline(size: 20, weight: FontWeight.w700, color: AppTheme.onSurface)),
              Text('حدّد وجهة توصيل طلباتك القادمة', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onDelete});
  final SavedAddress address;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 8, offset: Offset(0, 2))],
        border: address.isDefault ? Border.all(color: AppTheme.primaryContainer.withValues(alpha: 0.4), width: 1.5) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: address.isDefault ? AppTheme.primaryFixed : AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconForLabel(address.label), color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(address.label, style: AppTheme.headline(size: 15, weight: FontWeight.w700, color: AppTheme.onSurface))),
                  if (address.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.primaryContainer.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                      child: Text('افتراضي', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.primary, letterSpacing: 0.4)),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(address.addressText, style: AppTheme.body(size: 13, color: AppTheme.charcoalMuted, height: 20 / 13)),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف العنوان؟'),
                  content: Text('سيتم حذف "${address.label}" — لن يعود متاحاً لطلباتك القادمة.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
                    TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('حذف', style: TextStyle(color: AppTheme.pomegranateRed))),
                  ],
                ),
              );
              if (ok == true) onDelete();
            },
            icon: const Icon(Icons.delete_outline, color: AppTheme.pomegranateRed, size: 20),
          ),
        ],
      ),
    );
  }

  IconData _iconForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('منزل') || l.contains('بيت') || l.contains('home')) return Icons.home;
    if (l.contains('عمل') || l.contains('work') || l.contains('office')) return Icons.work_outline;
    return Icons.location_on;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 72, color: AppTheme.primaryContainer),
            const SizedBox(height: 12),
            Text('لا يوجد عناوين محفوظة', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('احفظ عناوين المنزل والعمل مرة واحدة لتوفير الوقت في كل طلب.',
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 13, color: AppTheme.charcoalMuted)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('إضافة عنوان'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryContainer, foregroundColor: AppTheme.onPrimary, minimumSize: const Size(220, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggedOutState extends StatelessWidget {
  const _LoggedOutState();
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
                const Icon(Icons.lock_outline, size: 72, color: AppTheme.primaryContainer),
                const SizedBox(height: 12),
                Text('يلزم تسجيل الدخول', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('العناوين المحفوظة تُربط بحسابك — سجّل دخولك للاستفادة منها.',
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
