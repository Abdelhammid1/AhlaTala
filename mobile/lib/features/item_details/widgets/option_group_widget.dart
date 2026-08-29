import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/item.dart';
import '../../../data/models/option.dart';
import '../../../data/models/option_group.dart';
import '../controllers/item_configuration_controller.dart';

/// Renders one OptionGroup according to selection_type (single vs multi).
/// The `kind` only affects labels/decoration (e.g. remove shows "-" prefix,
/// add shows "+"); the runtime behaviour is fully driven by selectionType.
class OptionGroupWidget extends ConsumerWidget {
  const OptionGroupWidget({super.key, required this.item, required this.group});
  final ItemDetail item;
  final OptionGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(itemConfigurationControllerProvider(item).notifier);
    final selections = ref
        .watch(itemConfigurationControllerProvider(item))
        .selectionsByGroupId[group.id] ?? const <int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(group.nameAr,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              if (group.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('إجباري',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('اختياري',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (var i = 0; i < group.options.length; i++) ...[
                _optionRow(context, controller, group.options[i], selections.contains(group.options[i].id)),
                if (i < group.options.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _optionRow(
    BuildContext context,
    ItemConfigurationController controller,
    Option opt,
    bool selected,
  ) {
    final theme = Theme.of(context);
    final priceLabel = _priceLabel(opt);
    final selector = group.selectionType == SelectionType.single
        ? IconButton(
            iconSize: 24,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? theme.colorScheme.primary : Colors.grey,
            ),
            onPressed: () => controller.toggle(group, opt),
          )
        : Checkbox(value: selected, onChanged: (_) => controller.toggle(group, opt));

    return InkWell(
      onTap: () => controller.toggle(group, opt),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            selector,
            Expanded(
              child: Text(opt.nameAr, style: const TextStyle(fontSize: 15)),
            ),
            if (priceLabel != null)
              Text(priceLabel,
                  style: TextStyle(
                      color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String? _priceLabel(Option opt) {
    if (group.kind == OptionGroupKind.remove) return null; // never a price on remove
    if (opt.priceDelta == 0) return null;
    final sign = opt.priceDelta > 0 ? '+' : '';
    return '$sign${opt.priceDelta.toStringAsFixed(2)} ريال';
  }
}
