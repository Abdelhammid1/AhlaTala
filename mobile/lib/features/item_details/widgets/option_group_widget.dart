import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/item.dart';
import '../../../data/models/option.dart';
import '../../../data/models/option_group.dart';
import '../controllers/item_configuration_controller.dart';

/// Renders one OptionGroup according to selection_type (single vs multi).
///
/// [highlightIfUnmet] — when true and the group is required but has no
/// selection yet, the small count-hint under the title turns red and a
/// red "⚠ مطلوب" pill is emphasised. The parent screen flips this after
/// the customer taps "إضافة" without satisfying every required group.
class OptionGroupWidget extends ConsumerWidget {
  const OptionGroupWidget({
    super.key,
    required this.item,
    required this.group,
    this.highlightIfUnmet = false,
  });
  final ItemDetail item;
  final OptionGroup group;
  final bool highlightIfUnmet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(itemConfigurationControllerProvider(item).notifier);
    final selections = ref
        .watch(itemConfigurationControllerProvider(item))
        .selectionsByGroupId[group.id] ?? const <int>{};
    final unmet = group.isRequired && selections.isEmpty;
    final showRedHint = unmet && highlightIfUnmet;

    // Subtitle text for required groups: "اختيار واحد" for single,
    // "N اختر" for multi-choice groups (N = max choices; falls back to
    // "اختر واحد على الأقل" when no max is enforced).
    String? subtitle;
    if (group.isRequired) {
      if (group.selectionType == SelectionType.single) {
        subtitle = 'اختيار واحد';
      } else {
        subtitle = 'اختر واحداً على الأقل';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Header row ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(group.nameAr,
                        style: AppTheme.headline(size: 16, weight: FontWeight.w700, color: AppTheme.onSurface)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTheme.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: showRedHint ? AppTheme.pomegranateRed : AppTheme.charcoalMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (group.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.pomegranateRed.withValues(alpha: showRedHint ? 1.0 : 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.error_outline,
                        size: 12,
                        color: showRedHint ? AppTheme.surfaceBright : AppTheme.pomegranateRed),
                    const SizedBox(width: 4),
                    Text('مطلوب',
                        style: AppTheme.body(
                          size: 10,
                          weight: FontWeight.w800,
                          color: showRedHint ? AppTheme.surfaceBright : AppTheme.pomegranateRed,
                          letterSpacing: 0.3,
                        )),
                  ]),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('اختياري',
                      style: AppTheme.body(size: 10, weight: FontWeight.w700, color: AppTheme.charcoalMuted, letterSpacing: 0.3)),
                ),
            ],
          ),
        ),
        // ---- Options list ----
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: AppTheme.surfaceContainerLowest,
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
    final priceLabel = _priceLabel(opt);
    final selector = group.selectionType == SelectionType.single
        ? IconButton(
            iconSize: 22,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppTheme.onSurface : AppTheme.outlineVariant,
            ),
            onPressed: () => controller.toggle(group, opt),
          )
        : Checkbox(
            value: selected,
            onChanged: (_) => controller.toggle(group, opt),
            activeColor: AppTheme.onSurface,
            side: const BorderSide(color: AppTheme.outlineVariant, width: 1.5),
          );

    return InkWell(
      onTap: () => controller.toggle(group, opt),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            selector,
            Expanded(
              child: Text(opt.nameAr,
                  style: AppTheme.body(size: 14, weight: FontWeight.w600, color: AppTheme.onSurface)),
            ),
            if (priceLabel != null)
              Text(priceLabel,
                  style: AppTheme.body(size: 12, weight: FontWeight.w700, color: AppTheme.herbFresh)),
          ],
        ),
      ),
    );
  }

  String? _priceLabel(Option opt) {
    if (group.kind == OptionGroupKind.remove) return null; // never a price on remove
    if (opt.priceDelta == 0) return null;
    final sign = opt.priceDelta > 0 ? '+' : '';
    return '$sign${opt.priceDelta.toStringAsFixed(0)} ر.س';
  }
}
