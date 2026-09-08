import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';

/// OTP verification — 6 boxes matching the Stitch design.
///
/// Backend contract is a 6-digit code (E9 US9.1/US9.2); the Stitch mockup
/// draws 4 boxes but we render 6 to match reality. Layout is otherwise
/// identical to the mockup — brand-cream digit tiles, active box with a
/// pulsing brand-orange caret, timer + resend row underneath.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.phone, this.devCode});
  final String phone;
  final String? devCode;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  static const int _digitCount = 6;
  final _hiddenCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;
  String? _lastDevCode;
  int _resendIn = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _lastDevCode = widget.devCode;
    if (_lastDevCode != null && _lastDevCode!.length == _digitCount) {
      _hiddenCtrl.text = _lastDevCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendIn = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = _resendIn - 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _hiddenCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _hiddenCtrl.text.trim();
    if (code.length != _digitCount) {
      setState(() => _error = 'الكود مكون من $_digitCount أرقام');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final res = await ref.read(authRepositoryProvider).verifyOtp(widget.phone, code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      setState(() => _error = res.errorMessage);
      _hiddenCtrl.clear();
      _focus.requestFocus();
      return;
    }
    await ref.read(authControllerProvider.notifier).set(res.value!);
    if (!mounted) return;
    context.go('/profile');
  }

  Future<void> _resend() async {
    setState(() { _busy = true; _error = null; });
    final res = await ref.read(authRepositoryProvider).requestOtp(widget.phone);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastDevCode = res.value?.devCode;
      if (_lastDevCode != null && _lastDevCode!.length == _digitCount) {
        _hiddenCtrl.text = _lastDevCode!;
      } else {
        _hiddenCtrl.clear();
      }
    });
    if (!res.ok) {
      setState(() => _error = res.errorMessage);
      return;
    }
    _startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال كود جديد')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back button row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
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
                    Text('التحقق من الكود', style: AppTheme.headline(size: 18, weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _OtpCard(
                phone: widget.phone,
                digitCount: _digitCount,
                controller: _hiddenCtrl,
                focus: _focus,
                onChanged: (v) {
                  setState(() {});
                  if (v.length == _digitCount && !_busy) _submit();
                },
                busy: _busy,
                error: _error,
                onEditPhone: () => context.pop(),
              ),
              const SizedBox(height: 16),
              // Dev code helper — visible only in local dev
              if (_lastDevCode != null && _lastDevCode!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'وضع التطوير — الكود التجريبي: '),
                          TextSpan(
                            text: _lastDevCode!,
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 2),
                          ),
                        ]),
                        style: const TextStyle(color: Color(0xFFF57F17), fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
              // Timer + resend
              Center(
                child: TextButton.icon(
                  onPressed: (_resendIn > 0 || _busy) ? null : _resend,
                  icon: Icon(
                    _resendIn > 0 ? Icons.hourglass_bottom : Icons.refresh,
                    size: 16,
                    color: _resendIn > 0 ? AppTheme.charcoalMuted : AppTheme.primaryContainer,
                  ),
                  label: Text(
                    _resendIn > 0
                        ? 'يمكنك إعادة الإرسال بعد $_resendIn ثانية'
                        : 'إعادة إرسال الكود',
                    style: AppTheme.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: _resendIn > 0 ? AppTheme.charcoalMuted : AppTheme.primaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: (_busy || _hiddenCtrl.text.length != _digitCount) ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: AppTheme.onPrimary,
                  disabledBackgroundColor: AppTheme.surfaceContainer,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: const Color(0x59E87722),
                ),
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary))
                    : Text('تحقق ومتابعة', style: AppTheme.body(size: 15, weight: FontWeight.w700, color: AppTheme.onPrimary)),
              ),
              const Spacer(),
              Text(
                'إذا لم يصلك الكود، تأكّد من صلاحية إشارة الجوال وأعد الطلب. '
                'في وضع التطوير يظهر الكود في سجل الخادم.',
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 11, color: AppTheme.charcoalMuted),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpCard extends StatelessWidget {
  const _OtpCard({
    required this.phone,
    required this.digitCount,
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.busy,
    required this.error,
    required this.onEditPhone,
  });
  final String phone;
  final int digitCount;
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final bool busy;
  final String? error;
  final VoidCallback onEditPhone;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.phone_iphone, size: 22, color: AppTheme.flameDeep),
            const SizedBox(width: 6),
            Text('أدخل رمز التحقق 📲', style: AppTheme.headline(size: 16, weight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('تم الإرسال إلى:', style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
            const SizedBox(width: 4),
            Text(phone, style: AppTheme.body(size: 13, weight: FontWeight.w700, color: AppTheme.onSurface)),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onEditPhone,
              style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
              child: Text('تعديل الرقم ✏️', style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.primary)),
            ),
          ]),
          const SizedBox(height: 16),
          // Digit tiles + hidden input
          Stack(
            children: [
              // The invisible text field the digit tiles read from — a plain
              // TextField owns the OS keyboard + cursor + backspace logic.
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(digitCount)],
                    onChanged: onChanged,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => focus.requestFocus(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(digitCount, (i) {
                    final has = i < controller.text.length;
                    final isActive = i == controller.text.length && focus.hasFocus;
                    return Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      child: Container(
                        width: 44, height: 56,
                        decoration: BoxDecoration(
                          color: has ? AppTheme.surfaceCream : AppTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive ? AppTheme.primaryContainer : AppTheme.outlineVariant,
                            width: isActive ? 2 : 1,
                          ),
                          boxShadow: isActive
                              ? const [BoxShadow(color: Color(0x59E87722), blurRadius: 20, offset: Offset(0, 8))]
                              : const [BoxShadow(color: Color(0x08000000), blurRadius: 4)],
                        ),
                        child: Center(
                          child: has
                              ? Text(
                                  controller.text[i],
                                  style: AppTheme.headline(size: 24, weight: FontWeight.w700, color: AppTheme.onSurface),
                                )
                              : (isActive
                                  ? const _BlinkingCaret()
                                  : const SizedBox.shrink()),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.error_outline, size: 14, color: AppTheme.pomegranateRed),
              const SizedBox(width: 4),
              Expanded(
                child: Text(error!, style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.pomegranateRed)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret();
  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(width: 2, height: 24, decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(2))),
    );
  }
}
