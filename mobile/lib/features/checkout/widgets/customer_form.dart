import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/checkout_controller.dart';

/// Customer name + phone for the checkout.
///
/// When the customer is signed in (E9 session present) the fields are
/// hidden and a compact identity chip renders instead — the name + phone
/// are seeded into the checkout controller from the session so submit()
/// still gets them without asking. Guest customers see the two editable
/// text fields exactly as before.
class CustomerForm extends ConsumerStatefulWidget {
  const CustomerForm({super.key});

  @override
  ConsumerState<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<CustomerForm> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final s = ref.watch(checkoutControllerProvider);
    final ctrl = ref.read(checkoutControllerProvider.notifier);

    // Signed-in path — seed the checkout controller from the session and
    // render a read-only identity chip. We reseed on every rebuild because
    // ctrl.setCustomerName / setCustomerPhone are cheap no-ops when the
    // value is unchanged.
    if (session != null) {
      final name = (session.customer.name ?? '').trim();
      final phone = session.customer.phone;
      if (s.customerName != name) {
        WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.setCustomerName(name));
      }
      if (s.customerPhone != phone) {
        WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.setCustomerPhone(phone));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 6),
            child: Text('بيانات العميل', style: AppTheme.headline(size: 15, weight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Color(0x0A1F1B19), blurRadius: 4)],
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(999)),
                  child: const Icon(Icons.person, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isEmpty ? 'حسابك' : name,
                        style: AppTheme.body(size: 14, weight: FontWeight.w700, color: AppTheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.phone, size: 12, color: AppTheme.charcoalMuted),
                        const SizedBox(width: 4),
                        Text(phone, style: AppTheme.body(size: 12, weight: FontWeight.w600, color: AppTheme.charcoalMuted)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.herbFresh.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.verified, size: 12, color: AppTheme.herbFresh),
                    const SizedBox(width: 4),
                    Text('موثّق', style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.herbFresh, letterSpacing: 0.4)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Guest path — the original name + phone form.
    if (!_hydrated) {
      _nameCtrl.text = s.customerName;
      _phoneCtrl.text = s.customerPhone;
      _hydrated = true;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 6),
          child: Text('بيانات العميل', style: AppTheme.headline(size: 15, weight: FontWeight.w700)),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: ctrl.setCustomerName,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: ctrl.setCustomerPhone,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
