import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/checkout_controller.dart';

/// Name + phone; deferred to E9 (accounts) but E3 needs them to reach the DB.
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
    final s = ref.watch(checkoutControllerProvider);
    if (!_hydrated) {
      _nameCtrl.text = s.customerName;
      _phoneCtrl.text = s.customerPhone;
      _hydrated = true;
    }
    final ctrl = ref.read(checkoutControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4, bottom: 6),
          child: Text('بيانات العميل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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
