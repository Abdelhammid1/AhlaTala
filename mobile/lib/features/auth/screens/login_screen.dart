import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';

/// Phone entry — matches the top half of the "تأكيد otp.html" Stitch mockup.
/// Posts to the real /auth/otp/request endpoint, then routes to /verify
/// with the phone and (in dev) the dev_code so testers don't have to peek
/// into the Flask console.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 4) {
      setState(() => _error = 'أدخل رقم جوال صحيح');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final res = await ref.read(authRepositoryProvider).requestOtp(phone);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      setState(() => _error = res.errorMessage);
      return;
    }
    final devCode = res.value?.devCode;
    final q = <String, String>{'phone': phone};
    if (devCode != null) q['dev_code'] = devCode;
    final query = q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    if (!mounted) return;
    context.push('/verify?$query');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Top bar — brand pill + guest browse shortcut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department, size: 18, color: AppTheme.flameDeep),
                      const SizedBox(width: 4),
                      Text('طازة وعالفحم', style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.charcoalSoft)),
                    ]),
                  ),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('تصفح كزائر', style: AppTheme.body(size: 14, weight: FontWeight.w600, color: AppTheme.charcoalMuted)),
                      const Icon(Icons.chevron_left, size: 18, color: AppTheme.charcoalMuted),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Brand hero card
              _BrandHero(),
              const SizedBox(height: 12),
              // Loyalty reward hook
              _LoyaltyReward(),
              const SizedBox(height: 16),
              // Phone field card
              _PhoneField(
                controller: _phoneCtrl,
                error: _error,
                enabled: !_busy,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: AppTheme.onPrimary,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: const Color(0x59E87722),
                ),
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary))
                    : Text('أرسل الكود', style: AppTheme.body(size: 15, weight: FontWeight.w700, color: AppTheme.onPrimary)),
              ),
              const SizedBox(height: 20),
              Text(
                'يمكنك تصفح المنيو والطلب كضيف — تسجيل الدخول يضيف نقاط الولاء وسجل الطلبات.',
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 128,
            child: Stack(fit: StackFit.expand, children: [
              // Brand-gradient fallback (in place of a photo)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight, end: Alignment.centerLeft,
                    colors: [AppTheme.flameDeep, AppTheme.primary, AppTheme.charcoalSoft],
                  ),
                ),
              ),
              // Ambient blur
              Positioned(
                right: -20, bottom: -20, width: 100, height: 100,
                child: DecoratedBox(decoration: BoxDecoration(color: AppTheme.amberVibrant.withValues(alpha: 0.3), shape: BoxShape.circle)),
              ),
              const Center(
                child: Icon(Icons.local_fire_department, size: 48, color: Color(0xE6FDE68A)),
              ),
              // Bottom fade
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppTheme.surfaceContainerLow],
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: AppTheme.primaryContainer, shape: BoxShape.circle),
                    child: const Icon(Icons.restaurant, color: AppTheme.onPrimary, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('حيّاك الله في أحلى طلة 🔥', style: AppTheme.headline(size: 20, weight: FontWeight.w700, color: AppTheme.onSurface)),
                        const SizedBox(height: 2),
                        Text('مشاوي · شاورما · عصائر طازجة', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.flameDeep, letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(
                  'سجّل برقم جوالك لطلب أشهى المشاوي والشاورما وجمع نقاط الولاء التلقائية مع كل وجبة.',
                  style: AppTheme.body(size: 14, color: AppTheme.onSurfaceVariant, height: 22 / 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyReward extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4)],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: AppTheme.goldLight.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.card_giftcard, color: AppTheme.tertiary, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('هدية تسجيل الدخول', style: AppTheme.headline(size: 15, weight: FontWeight.w600, color: AppTheme.tertiary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppTheme.amberVibrant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                  child: Text('+50 نقطة', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.onPrimaryContainer, letterSpacing: 0.4)),
                ),
              ]),
              const SizedBox(height: 2),
              Text('احصل على 50 نقطة ولاء مجانية عند إتمام أول طلب!', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.error, required this.enabled, required this.onSubmitted});
  final TextEditingController controller;
  final String? error;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Row(children: [
                const Icon(Icons.call, size: 20, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text('رقم الجوال', style: AppTheme.body(size: 14, weight: FontWeight.w600, color: AppTheme.onSurface, letterSpacing: 0.2)),
              ]),
              const Spacer(),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified, size: 14, color: AppTheme.herbFresh),
                const SizedBox(width: 2),
                Text('تحقق آمن وفوري', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.herbFresh, letterSpacing: 0.4)),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🇸🇦', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text('+966', style: AppTheme.priceTag(color: AppTheme.charcoalSoft)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCream,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1))],
                ),
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: AppTheme.priceTag(color: AppTheme.onSurface),
                  onSubmitted: onSubmitted,
                  decoration: InputDecoration(
                    hintText: '5X XXX XXXX',
                    hintStyle: AppTheme.body(size: 14, color: AppTheme.charcoalMuted.withValues(alpha: 0.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: InputBorder.none,
                    filled: false,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.cancel, size: 18, color: AppTheme.charcoalMuted),
                      onPressed: () => controller.clear(),
                    ),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          if (error != null)
            Text(error!, style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.pomegranateRed))
          else
            Row(children: [
              const Icon(Icons.sms_outlined, size: 14, color: AppTheme.charcoalMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text('سنرسل لك رمز تحقق سريع مكوّن من 6 أرقام عبر رسالة SMS', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
              ),
            ]),
        ],
      ),
    );
  }
}
