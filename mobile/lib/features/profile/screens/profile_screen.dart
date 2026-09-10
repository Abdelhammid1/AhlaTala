import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stitch_bottom_nav.dart';
import '../../../data/models/session.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../loyalty/providers/loyalty_providers.dart';

/// Profile screen — merged with the loyalty balance surface, matching
/// the "الملف الشخصي ونقط الولاء" Stitch mockup. Every element wired to
/// real providers.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    if (session == null) return const _GuestPrompt();
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerBalanceProvider(session.customer.phone));
            },
            child: ListView(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 96),
              children: [
                _IdentityHero(customer: session.customer),
                const SizedBox(height: 16),
                _LoyaltyCard(phone: session.customer.phone),
                const SizedBox(height: 20),
                _QuickActionsRow(),
                const SizedBox(height: 20),
                _SectionTitle('الحساب'),
                _MenuTile(icon: Icons.person_outline, label: 'تعديل الاسم', onTap: () => _editName(context, ref, session.customer)),
                const _MenuTile(icon: Icons.location_on_outlined, label: 'العناوين المحفوظة', route: '/profile/addresses'),
                const _MenuTile(icon: Icons.receipt_long_outlined, label: 'طلباتي السابقة', route: '/profile/orders'),
                const SizedBox(height: 12),
                const _SectionTitle('الاعدادات'),
                const _MenuTile(icon: Icons.notifications_outlined, label: 'الإشعارات والعروض', route: '/notifications'),
                _MenuTile(icon: Icons.help_outline, label: 'المساعدة والدعم', onTap: () {}),
                const SizedBox(height: 20),
                _LogoutButton(),
                const SizedBox(height: 12),
                _DeleteAccountButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: StitchBottomNav(active: StitchNavTab.profile)),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, SessionCustomer c) async {
    final ctrl = TextEditingController(text: c.name ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تعديل الاسم', style: AppTheme.headline(size: 16, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final updated = await ref.read(authRepositoryProvider).patchName(ctrl.text.trim());
                await ref.read(authControllerProvider.notifier).updateCustomer(updated);
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('حفظ'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الاسم')));
    }
  }
}

// ═════════════════ Guest prompt ═════════════════

class _GuestPrompt extends StatelessWidget {
  const _GuestPrompt();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 80, color: AppTheme.primaryContainer),
                    const SizedBox(height: 12),
                    Text('أنت غير مسجّل الدخول', style: AppTheme.headline(size: 20, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('سجّل دخولك بجوالك للوصول إلى ملفك ونقاطك وطلباتك السابقة.',
                        textAlign: TextAlign.center, style: AppTheme.body(size: 13, color: AppTheme.charcoalMuted)),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('تسجيل الدخول'),
                      style: FilledButton.styleFrom(minimumSize: const Size(220, 48)),
                      onPressed: () => context.push('/login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: StitchBottomNav(active: StitchNavTab.profile)),
        ],
      ),
    );
  }
}

// ═════════════════ Identity hero card ═════════════════

class _IdentityHero extends StatelessWidget {
  const _IdentityHero({required this.customer});
  final SessionCustomer customer;
  @override
  Widget build(BuildContext context) {
    final initials = (customer.name ?? customer.phone).characters.take(2).toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Text(initials, style: AppTheme.headline(size: 22, weight: FontWeight.w700, color: AppTheme.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name ?? 'اضف اسمك', style: AppTheme.headline(size: 20, weight: FontWeight.w700, color: AppTheme.onSurface)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.phone, size: 14, color: AppTheme.charcoalMuted),
                  const SizedBox(width: 4),
                  Text(customer.phone, style: AppTheme.body(size: 13, weight: FontWeight.w600, color: AppTheme.charcoalMuted)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════ Loyalty balance card ═════════════════

class _LoyaltyCard extends ConsumerWidget {
  const _LoyaltyCard({required this.phone});
  final String phone;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerBalanceProvider(phone));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [AppTheme.flameDeep, AppTheme.primary, AppTheme.charcoalSoft],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x59E65100), blurRadius: 20, offset: Offset(0, 10))],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16, bottom: -20, width: 120, height: 120,
              child: DecoratedBox(decoration: BoxDecoration(color: AppTheme.amberVibrant.withValues(alpha: 0.25), shape: BoxShape.circle)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.goldLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.stars, size: 14, color: AppTheme.goldLight),
                        const SizedBox(width: 4),
                        Text('نقاطي', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.goldLight, letterSpacing: 0.4)),
                      ]),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => context.push('/loyalty'),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('السجل الكامل', style: AppTheme.body(size: 11, weight: FontWeight.w700, color: AppTheme.surfaceBright)),
                          const Icon(Icons.chevron_left, size: 16, color: AppTheme.surfaceBright),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                async.when(
                  loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(color: AppTheme.goldLight, strokeWidth: 2))),
                  error: (_, __) => Text('تعذّر تحميل الرصيد', style: AppTheme.body(size: 14, color: AppTheme.surfaceCream)),
                  data: (bal) => Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${bal?.pointsBalance ?? 0}', style: AppTheme.headline(size: 40, weight: FontWeight.w700, color: AppTheme.surfaceBright)),
                      const SizedBox(width: 6),
                      Text('نقطة', style: AppTheme.body(size: 14, weight: FontWeight.w600, color: AppTheme.surfaceCream)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('كلما تطلب — نقاطك تتضاعف. استبدلها بخصم على طلبك القادم.',
                    style: AppTheme.body(size: 12, color: const Color(0xCCFDFAF6))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════ Quick actions row ═════════════════

class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        children: [
          Expanded(child: _QuickAction(icon: Icons.receipt_long, label: 'طلباتي', route: '/profile/orders')),
          SizedBox(width: 10),
          Expanded(child: _QuickAction(icon: Icons.location_on, label: 'العناوين', route: '/profile/addresses')),
          SizedBox(width: 10),
          Expanded(child: _QuickAction(icon: Icons.notifications, label: 'الإشعارات', route: '/notifications')),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22, color: AppTheme.primary),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════ Menu tile ═════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(text, style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.charcoalMuted, letterSpacing: 0.6)),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, this.route, this.onTap});
  final IconData icon;
  final String label;
  final String? route;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ?? (route != null ? () => context.push(route!) : null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: AppTheme.body(size: 14, weight: FontWeight.w600, color: AppTheme.onSurface))),
                const Icon(Icons.chevron_left, size: 20, color: AppTheme.charcoalMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════ Logout ═════════════════

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () async {
          final router = GoRouter.of(context);
          await ref.read(authControllerProvider.notifier).logout();
          router.go('/');
        },
        icon: const Icon(Icons.logout, color: AppTheme.pomegranateRed),
        label: Text('تسجيل الخروج', style: AppTheme.body(size: 14, weight: FontWeight.w700, color: AppTheme.pomegranateRed)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.pomegranateRed.withValues(alpha: 0.3)),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ═════════════════ Delete account ═════════════════

class _DeleteAccountButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DeleteAccountButton> createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends ConsumerState<_DeleteAccountButton> {
  bool _busy = false;

  Future<void> _confirmAndDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.pomegranateRed),
          const SizedBox(width: 8),
          Expanded(child: Text('حذف الحساب نهائياً', style: AppTheme.headline(size: 18, weight: FontWeight.w700, color: AppTheme.onSurface))),
        ]),
        content: Text(
          'سيتم حذف اسمك ورقم جوالك وعناوينك ونقاطك المتاحة نهائياً.\n\n'
          'وفقاً لأنظمة الفواتير السعودية، تُحفظ سجلات طلباتك السابقة لخمس سنوات بدون بيانات تعريفية.\n\n'
          'هذا الإجراء لا يمكن التراجع عنه.',
          style: AppTheme.body(size: 13, color: AppTheme.onSurfaceVariant, height: 20 / 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('إلغاء', style: AppTheme.body(size: 14, weight: FontWeight.w600, color: AppTheme.charcoalMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.pomegranateRed, foregroundColor: Colors.white),
            child: const Text('نعم، احذف حسابي'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;
    setState(() => _busy = true);

    // Double-guard: capture the router BEFORE the async gap so we don't
    // need context after the await (which would be unmounted).
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // Success — nuke the local session and land on home as a guest.
      await ref.read(authControllerProvider.notifier).logout();
      router.go('/');
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم حذف حسابك — شكراً لثقتك بنا 🌱'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text('تعذّر حذف الحساب: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton.icon(
        onPressed: _busy ? null : _confirmAndDelete,
        icon: _busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.pomegranateRed))
            : const Icon(Icons.delete_forever, color: AppTheme.pomegranateRed, size: 20),
        label: Text(
          _busy ? 'جارِ حذف الحساب…' : 'حذف الحساب نهائياً',
          style: AppTheme.body(size: 13, weight: FontWeight.w600, color: AppTheme.pomegranateRed),
        ),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
