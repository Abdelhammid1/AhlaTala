import 'package:flutter/material.dart';

import '../../../core/widgets/food_image.dart';
import '../../../data/models/item.dart';

/// One item row on the "items in category" screen.
///
/// Implements US1.1's copy rule: when [ItemSummary.priceIsVariable] is true
/// (there's a variant/size group with differing prices), show
/// "يبدأ من {displayPriceFrom} ريال" instead of the flat base price.
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, required this.onTap});

  final ItemSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92, height: 92,
                  child: FoodImage(url: item.imageUrl, icon: Icons.fastfood, iconSize: 32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.nameAr,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (item.calories != null) ...[
                      const SizedBox(height: 4),
                      Text('${item.calories} سعرة',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                    const SizedBox(height: 6),
                    _priceLine(context, item),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceLine(BuildContext context, ItemSummary it) {
    final theme = Theme.of(context);
    if (it.priceIsVariable && it.displayPriceFrom != null) {
      return Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'يبدأ من '),
          TextSpan(
            text: '${it.displayPriceFrom!.toStringAsFixed(2)} ريال',
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
          ),
        ]),
        style: const TextStyle(fontSize: 14),
      );
    }
    return Text(
      '${it.basePrice.toStringAsFixed(2)} ريال',
      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14),
    );
  }
}
