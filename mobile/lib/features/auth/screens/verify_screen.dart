import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';

/// US9.1/US9.2 — 6-digit OTP entry + resend cooldown.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.phone, this.devCode});
  final String phone;
  final String? devCode;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _lastDevCode;
  int _resendIn = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _lastDevCode = widget.devCode;
    if (_lastDevCode != null && _lastDevCode!.length == 6) {
      _codeCtrl.text = _lastDevCode!;
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
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'الكود مكون من 6 أرقام');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final res = await ref.read(authRepositoryProvider).verifyOtp(widget.phone, code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      setState(() => _error = res.errorMessage);
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
      if (_lastDevCode != null && _lastDevCode!.length == 6) {
        _codeCtrl.text = _lastDevCode!;
      } else {
        _codeCtrl.clear();
      }
    });
    if (!res.ok) {
      setState(() => _error = res.errorMessage);
      return;
    }
    _startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال كود جديد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من الكود')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Center(child: Text('أدخل الكود المرسل إلى ${widget.phone}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              if (_lastDevCode != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
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
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 22, letterSpacing: 12, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  counterText: '',
                  errorText: _error,
                  hintText: '••••••',
                ),
                onChanged: (v) {
                  if (v.length == 6 && !_busy) _submit();
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('تحقق'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: (_resendIn > 0 || _busy) ? null : _resend,
                  child: Text(_resendIn > 0
                      ? 'إعادة الإرسال بعد $_resendIn ثانية'
                      : 'إعادة إرسال الكود'),
                ),
              ),
              const Spacer(),
              Text(
                'في وضع التطوير سيظهر الكود في سجل الخادم (Flask console). '
                'سيتم استبداله بموفر SMS حقيقي لاحقاً.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
