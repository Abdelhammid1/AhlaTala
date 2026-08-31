import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/food_image.dart';
import '../../../data/models/cart_line.dart';
import '../providers/cart_controller.dart';

/// One line in the cart list. Image + name + option chips + qty stepper + delete.
class CartLineTile extends ConsumerWidget {
  const CartLineTile({super.key, required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(cartControllerProvider.notifier);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 74, height: 74,
                child: FoodImage(url: line.imageUrl, icon: Icons.fastfood, iconSize: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(line.nameAr,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.delete_outline, color: Colors.grey.shade700),
                        onPressed: () => controller.removeLine(line.id),
                      ),
                    ],
                  ),
                  if (line.selections.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: -4,
                      children: [
                        for (final s in line.selections)
                          _selectionChip(s),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _qtyStepper(controller),
                      const Spacer(),
                      Text('${line.linePrice.toStringAsFixed(2)} ريال',
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionChip(CartLineSelection s) {
    final prefix = switch (s.groupKind) {
      'remove' => '−',
      'add' => '+',
      _ => '',
    };
    final label = prefix.isEmpty ? s.optionNameAr : '$prefix ${s.optionNameAr}';
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: EdgeInsets.zero,
    );
  }

  Widget _qtyStepper(CartController controller) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove, () => controller.updateQuantity(line.id, line.quantity - 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('${line.quantity}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          _stepBtn(Icons.add, () => controller.updateQuantity(line.id, line.quantity + 1)),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18),
        ),
      );
}
