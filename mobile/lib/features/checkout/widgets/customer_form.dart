import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/checkout_controller.dart';

/// Bottom-sheet name editor reused from the profile flow — writes to
/// PATCH /me and mirrors the new value into the auth controller so
/// every downstream screen (header greeting, order snapshot, checkout
/// identity chip) refreshes in-place.
Future<void> _openNameEditor(BuildContext context, WidgetRef ref, {required String initial}) async {
  final ctrl = TextEditingController(text: initial);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 4,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('اكتب اسمك', style: AppTheme.headline(size: 16, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('يظهر لسائق التوصيل مع الطلب',
              style: AppTheme.body(size: 12, color: AppTheme.charcoalMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'مثال: خالد سلطان',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.length < 2) return;
              try {
                final updated = await ref.read(authRepositoryProvider).patchName(name);
                await ref.read(authControllerProvider.notifier).updateCustomer(updated);
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('تعذّر حفظ الاسم — حاول مرة أخرى')),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

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
    // render a read-only identity chip. If the customer signed up with
    // phone+OTP only (name is empty) we fall back to a friendly default
    // ('عميل') so the CheckoutState.canSubmit min-length check doesn't
    // stall the whole flow with no visible input to fix it.
    if (session != null) {
      final rawName = (session.customer.name ?? '').trim();
      final effectiveName = rawName.isEmpty ? 'عميل' : rawName;
      final phone = session.customer.phone;
      if (s.customerName != effectiveName) {
        WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.setCustomerName(effectiveName));
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
                      Row(children: [
                        Expanded(
                          child: Text(
                            effectiveName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(size: 14, weight: FontWeight.w700, color: AppTheme.onSurface),
                          ),
                        ),
                        // Inline "تعديل" link — opens a small name-edit
                        // sheet so the customer can add / change their
                        // name without leaving the checkout.
                        InkWell(
                          onTap: () => _openNameEditor(context, ref, initial: rawName),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.edit_outlined, size: 12, color: AppTheme.primary),
                              const SizedBox(width: 2),
                              Text('تعديل',
                                  style: AppTheme.body(size: 11, weight: FontWeight.w800, color: AppTheme.primary)),
                            ]),
                          ),
                        ),
                      ]),
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
