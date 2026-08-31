import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/food_image.dart';
import '../../cart/providers/cart_controller.dart';
import '../../cart/widgets/cart_badge.dart';
import '../../cart/widgets/cross_sell_sheet.dart';
import '../../menu/providers/menu_providers.dart';
import '../controllers/item_configuration_controller.dart';
import '../widgets/nutrition_sheet.dart';
import '../widgets/option_group_widget.dart';

/// The item details screen.
///
/// E1 scope note: the "add to cart" button is fully wired to the controller
/// (correctly enabled/disabled based on required groups) but its action is a
/// stub — the cart lives in E2. When E2 lands, replace `_stubAdd` with the
/// real cart-add call; nothing else on this screen needs to change.
class ItemDetailsScreen extends ConsumerWidget {
  const ItemDetailsScreen({super.key, required this.itemId});
  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemDetailProvider(itemId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('خطأ: $e')),
      ),
      data: (item) {
        final state = ref.watch(itemConfigurationControllerProvider(item));
        return Scaffold(
          appBar: AppBar(
            title: Text(state.displayName),
            actions: [
              IconButton(
                icon: const Icon(Icons.local_dining_outlined),
                tooltip: 'الحقائق الغذائية',
                onPressed: () => NutritionSheet.show(context, item),
              ),
              const CartBadge(),
            ],
          ),
          body: ListView(
            children: [
              // hero image (swaps when a variant is picked)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: FoodImage(url: state.displayImageUrl, icon: Icons.fastfood, iconSize: 64),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.displayName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    if (item.descriptionAr != null && item.descriptionAr!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item.descriptionAr!, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, children: [
                      if (item.calories != null)
                        Chip(
                          avatar: const Icon(Icons.local_fire_department_outlined, size: 16),
                          label: Text('${item.calories} سعرة'),
                        ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final g in item.optionGroups) OptionGroupWidget(item: item, group: g),
              const SizedBox(height: 96),
            ],
          ),
          bottomNavigationBar: _BottomCta(itemId: itemId),
        );
      },
    );
  }
}

class _BottomCta extends ConsumerWidget {
  const _BottomCta({required this.itemId});
  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemDetailProvider(itemId));
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (item) {
        final state = ref.watch(itemConfigurationControllerProvider(item));
        final can = state.canAddToCart;
        return SafeArea(
          minimum: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!can)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'اختر: ${state.missingRequiredNames.join('، ')}',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              FilledButton(
                onPressed: can ? () => _addToCart(context, ref, item.id) : null,
                child: Text('أضف إلى السلة  •  ${state.totalPrice.toStringAsFixed(2)} ريال'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// E2 wiring: snapshot the current configuration into a cart line, confirm
  /// with a snackbar, and slide up the cross-sell sheet (US2.4).
  void _addToCart(BuildContext context, WidgetRef ref, int itemId) {
    final detail = ref.read(itemDetailProvider(itemId)).valueOrNull;
    if (detail == null) return;
    final cfg = ref.read(itemConfigurationControllerProvider(detail));
    final ok = ref.read(cartControllerProvider.notifier).addLineFromConfiguration(cfg);
    if (!ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة ${cfg.displayName} إلى السلة'),
        duration: const Duration(seconds: 1),
      ),
    );
    // Fire the sheet after the frame settles so the snackbar isn't overlapped.
    Future.microtask(() {
      if (!context.mounted) return;
      CrossSellSheet.show(context, itemId);
    });
  }
}
