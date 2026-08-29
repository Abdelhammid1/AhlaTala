import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/item.dart';
import '../../../data/repositories/menu_repository.dart';
import '../providers/cart_controller.dart';
import '../providers/cross_sells_provider.dart';

/// Bottom sheet shown after adding an item to the cart (US2.4).
/// A horizontal list of ItemSummary cards, each with a quick-add button.
class CrossSellSheet extends ConsumerWidget {
  const CrossSellSheet({super.key, required this.forItemId});
  final int forItemId;

  static Future<void> show(BuildContext context, int forItemId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      showDragHandle: true,
      builder: (_) => CrossSellSheet(forItemId: forItemId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crossSellsProvider(forItemId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('غالباً ما يُطلب معه',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('تعذّر التحميل', style: TextStyle(color: Colors.grey.shade600))),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                        child: Text('لا توجد مقترحات لهذا الصنف حالياً',
                            style: TextStyle(color: Colors.grey.shade600)));
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _CrossSellCard(item: items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrossSellCard extends ConsumerWidget {
  const _CrossSellCard({required this.item});
  final ItemSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    _priceLabel(item),
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: FilledButton.tonal(
                onPressed: () => _quickAdd(context, ref),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(28), padding: EdgeInsets.zero),
                child: const Text('+ إضافة', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
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

  Future<void> _quickAdd(BuildContext context, WidgetRef ref) async {
    // Fetch the full detail so we know whether the item has required groups.
    // Items without required groups add in one tap; anything else opens the
    // details screen so the customer completes the required choices.
    try {
      final detail = await ref.read(menuRepositoryProvider).fetchItem(item.id);
      final hasRequired = detail.optionGroups.any((g) => g.isRequired);
      if (!context.mounted) return;
      if (hasRequired) {
        Navigator.of(context).pop(); // close the sheet
        context.push('/items/${item.id}');
        return;
      }
      final ok = ref.read(cartControllerProvider.notifier).addBareItem(detail);
      if (!context.mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تمت إضافة ${detail.nameAr}'), duration: const Duration(seconds: 1)),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّرت الإضافة، حاول لاحقاً')),
      );
    }
  }
}
