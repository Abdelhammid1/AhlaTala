import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../notifications/providers/notifications_providers.dart';
import '../providers/loyalty_providers.dart';

/// "نقاطي" — loyalty balance + ledger.
///
/// If the user is signed in (E9 session present), we skip the phone entry
/// and auto-load the balance for `session.customer.phone`. Guests still
/// see the manual lookup form so pre-login flows keep working.
class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen> {
  final _phoneCtrl = TextEditingController();
  String _submittedPhone = '';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    // Signed-in path: skip the form entirely, drive off the session phone.
    final phone = session?.customer.phone ?? _submittedPhone;

    return Scaffold(
      appBar: AppBar(title: const Text('نقاطي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (session == null) _phoneLookupCard(),
          if (session == null) const SizedBox(height: 12),
          if (phone.isNotEmpty) _balanceAndLedger(phone),
        ],
      ),
    );
  }

  Widget _phoneLookupCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل رقم الجوال لعرض رصيدك',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '05xxxxxxxx',
                  ),
                  onSubmitted: (v) => setState(() => _submittedPhone = v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              // Wrap in IntrinsicWidth so the button doesn't receive the Row's
              // infinite main-axis constraint from Flex's non-flex layout pass.
              IntrinsicWidth(
                child: FilledButton(
                  onPressed: () => setState(() => _submittedPhone = _phoneCtrl.text.trim()),
                  child: const Text('عرض'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _balanceAndLedger(String phone) {
    final theme = Theme.of(context);
    return Consumer(builder: (context, ref, _) {
      final async = ref.watch(customerBalanceProvider(phone));
      return async.when(
        loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () {
            // ignore: unused_result
            ref.refresh(customerBalanceProvider(phone));
          },
        ),
        data: (bal) {
          if (bal == null) {
            return _msg('لا يوجد حساب مسجّل لهذا الرقم بعد.\nاطلب أول طلب لك وسنبدأ حساب النقاط.');
          }
          // Remember phone so inbox + future orders don't need re-entry.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(savedPhoneProvider.notifier).save(phone);
          });
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: theme.colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.stars_rounded, color: Colors.white, size: 42),
                      const SizedBox(height: 6),
                      Text('${bal.pointsBalance}',
                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                      const Text('نقطة متاحة',
                          style: TextStyle(color: Colors.white70)),
                      if (bal.name != null) ...[
                        const SizedBox(height: 6),
                        Text(bal.name!,
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('سجل النقاط',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Consumer(builder: (context, ref, _) {
                final ledgerAsync = ref.watch(ledgerProvider(bal.customerId));
                return ledgerAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => ErrorView(
                    error: e,
                    onRetry: () {
                      // ignore: unused_result
                      ref.refresh(ledgerProvider(bal.customerId));
                    },
                  ),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return _msg('لا يوجد نشاط بعد.');
                    }
                    return Column(
                      children: [
                        for (final e in entries)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                e.delta > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                                color: e.delta > 0 ? Colors.green.shade600 : Colors.red.shade600,
                              ),
                              title: Text(e.reasonAr),
                              subtitle: e.note != null ? Text(e.note!) : null,
                              trailing: Text(
                                '${e.delta > 0 ? '+' : ''}${e.delta}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: e.delta > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              }),
            ],
          );
        },
      );
    });
  }

  Widget _msg(String s) => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text(s, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700))),
      );
}
