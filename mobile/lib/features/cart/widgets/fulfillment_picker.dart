import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fulfillment.dart';
import '../providers/cart_controller.dart';

/// Segmented control + conditional address field. Writes changes straight
/// into CartController via `setFulfillment`.
class FulfillmentPicker extends ConsumerStatefulWidget {
  const FulfillmentPicker({super.key});

  @override
  ConsumerState<FulfillmentPicker> createState() => _FulfillmentPickerState();
}

class _FulfillmentPickerState extends ConsumerState<FulfillmentPicker> {
  final _addressCtrl = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ful = ref.watch(cartControllerProvider.select((s) => s.fulfillment));
    if (!_hydrated) {
      _addressCtrl.text = ful.address ?? '';
      _hydrated = true;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4, bottom: 6),
            child: Text('طريقة الاستلام',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          SegmentedButton<FulfillmentType>(
            segments: const [
              ButtonSegment(
                value: FulfillmentType.delivery,
                icon: Icon(Icons.delivery_dining_outlined),
                label: Text('توصيل'),
              ),
              ButtonSegment(
                value: FulfillmentType.pickup,
                icon: Icon(Icons.storefront_outlined),
                label: Text('استلام من الفرع'),
              ),
            ],
            selected: ful.type == FulfillmentType.none
                ? const <FulfillmentType>{}
                : {ful.type},
            emptySelectionAllowed: true,
            onSelectionChanged: (s) {
              final t = s.first;
              ref.read(cartControllerProvider.notifier).setFulfillment(
                    t,
                    address: t == FulfillmentType.delivery ? _addressCtrl.text : null,
                  );
            },
          ),
          if (ful.type == FulfillmentType.delivery) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'عنوان التوصيل',
                hintText: 'حي، شارع، ملاحظات للسائق…',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
              onChanged: (v) => ref
                  .read(cartControllerProvider.notifier)
                  .setFulfillment(FulfillmentType.delivery, address: v),
            ),
          ],
        ],
      ),
    );
  }
}
