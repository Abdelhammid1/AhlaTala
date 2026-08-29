import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/brand_logo.dart';
import '../../../data/repositories/auth_repository.dart';

/// US9.1/US9.2 — phone input, sends OTP, routes to /verify.
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
    // Dev convenience: if the backend handed us the code back (LoggingSender +
    // DEBUG), forward it to the verify screen so testers don't have to peek
    // into the Flask console.
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
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Center(child: BrandLogo(height: 140)),
              const SizedBox(height: 20),
              const Center(child: Text('أدخل رقم جوالك',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              const SizedBox(height: 4),
              Center(child: Text('سنرسل لك كود تحقق لتسجيل الدخول',
                  style: TextStyle(color: Colors.grey.shade700))),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'رقم الجوال',
                  hintText: '05xxxxxxxx',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('أرسل الكود'),
              ),
              const Spacer(),
              Text('يمكنك أيضاً تصفح المنيو والطلب كضيف دون تسجيل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('متابعة كضيف'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
