import 'package:flutter/material.dart';

import '../../../data/models/item.dart';

/// Simple bottom sheet showing what we know about the item's nutrition.
/// E1 keeps it small — only calories are stored. Later Epics can add fat/carbs/protein.
class NutritionSheet extends StatelessWidget {
  const NutritionSheet({super.key, required this.item});
  final ItemDetail item;

  static Future<void> show(BuildContext context, ItemDetail item) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => NutritionSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الحقائق الغذائية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _row('السعرات الحرارية', item.calories?.toString() ?? '—', 'كيلو كالوري'),
            const Divider(),
            Text('البيانات المتاحة حالياً محدودة. سيتم إضافة المزيد من التفاصيل قريباً.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, String unit) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
            Text(value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      );
}
