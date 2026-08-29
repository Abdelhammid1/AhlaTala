import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/item.dart';

class MostOrderedTile extends StatelessWidget {
  const MostOrderedTile({super.key, required this.item});
  final ItemSummary item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: () => context.push('/items/${item.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: item.imageUrl != null
                    ? CachedNetworkImage(imageUrl: item.imageUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.grey.shade200, child: const Icon(Icons.fastfood, size: 28)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nameAr,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_priceLabel(item),
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _priceLabel(ItemSummary it) {
    if (it.priceIsVariable && it.displayPriceFrom != null) {
      return 'يبدأ من ${it.displayPriceFrom!.toStringAsFixed(2)} ريال';
    }
    return '${it.basePrice.toStringAsFixed(2)} ريال';
  }
}
