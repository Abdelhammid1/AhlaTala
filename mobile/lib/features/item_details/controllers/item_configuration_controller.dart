import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/item.dart';
import '../../../data/models/option.dart';
import '../../../data/models/option_group.dart';

/// Holds the user's current selections for one item and derives everything
/// the details screen needs: running total, display image/name (variant swap),
/// and whether the CTA can fire (all required groups satisfied).
///
/// The engine is fully generic across the 4 option-group kinds:
///   - single-select groups store 0 or 1 selected option id per group
///   - multi-select groups store any number
///   - price = base_price + Σ price_delta of every selected option
///   - image / display name are swapped by the first selected option of the
///     first `variant` group that carries the override
///
/// This class is the seam E2 will plug into to construct a cart line.
class ItemConfigurationState {
  final ItemDetail item;
  final Map<int, Set<int>> selectionsByGroupId;

  const ItemConfigurationState({required this.item, required this.selectionsByGroupId});

  ItemConfigurationState copyWith({Map<int, Set<int>>? selectionsByGroupId}) =>
      ItemConfigurationState(
        item: item,
        selectionsByGroupId: selectionsByGroupId ?? this.selectionsByGroupId,
      );

  // ------- derived -------

  Iterable<Option> get _selectedOptions sync* {
    for (final g in item.optionGroups) {
      final ids = selectionsByGroupId[g.id] ?? const <int>{};
      for (final o in g.options) {
        if (ids.contains(o.id)) yield o;
      }
    }
  }

  double get totalPrice {
    double total = item.basePrice;
    for (final o in _selectedOptions) {
      total += o.priceDelta;
    }
    return total;
  }

  /// The image to show: first variant group's selected option image if any,
  /// else the item's own image.
  String? get displayImageUrl {
    for (final g in item.optionGroups) {
      if (g.kind != OptionGroupKind.variant) continue;
      final ids = selectionsByGroupId[g.id] ?? const <int>{};
      for (final o in g.options) {
        if (ids.contains(o.id) && o.imageUrl != null) return o.imageUrl;
      }
    }
    return item.imageUrl;
  }

  /// Display name: first variant group's selected option name (if any),
  /// else the item's Arabic name. Satisfies US1.6's "يغير اسم الصنف".
  String get displayName {
    for (final g in item.optionGroups) {
      if (g.kind != OptionGroupKind.variant) continue;
      final ids = selectionsByGroupId[g.id] ?? const <int>{};
      for (final o in g.options) {
        if (ids.contains(o.id)) return o.nameAr;
      }
    }
    return item.nameAr;
  }

  /// A required group is satisfied when it has ≥1 selection.
  bool get canAddToCart {
    for (final g in item.optionGroups) {
      if (!g.isRequired) continue;
      final ids = selectionsByGroupId[g.id] ?? const <int>{};
      if (ids.isEmpty) return false;
    }
    return true;
  }

  /// Human-readable list of unmet required groups — used to disable the CTA hint.
  List<String> get missingRequiredNames => [
        for (final g in item.optionGroups)
          if (g.isRequired && (selectionsByGroupId[g.id] ?? const <int>{}).isEmpty) g.nameAr,
      ];
}

class ItemConfigurationController extends StateNotifier<ItemConfigurationState> {
  ItemConfigurationController(ItemDetail item)
      : super(ItemConfigurationState(
          item: item,
          selectionsByGroupId: _seedDefaults(item),
        ));

  static Map<int, Set<int>> _seedDefaults(ItemDetail item) {
    final map = <int, Set<int>>{};
    for (final g in item.optionGroups) {
      map[g.id] = <int>{};
      // Pre-select the default option of single-select groups so the price
      // starts sensible and required groups start satisfied when possible.
      if (g.selectionType == SelectionType.single) {
        final def = g.options.where((o) => o.isDefault).cast<Option?>().firstWhere(
              (_) => true,
              orElse: () => null,
            );
        if (def != null) map[g.id]!.add(def.id);
      }
    }
    return map;
  }

  /// Toggle an option within its group; the group's selection_type decides
  /// whether picking one clears the others.
  void toggle(OptionGroup group, Option opt) {
    final selections = {
      for (final e in state.selectionsByGroupId.entries) e.key: {...e.value},
    };
    final current = selections[group.id] ?? <int>{};

    if (group.selectionType == SelectionType.single) {
      // Single: tapping the currently-selected option is a no-op for required
      // groups (can't clear the only choice) and a clear for optional groups.
      if (current.contains(opt.id)) {
        if (!group.isRequired) current.clear();
      } else {
        current
          ..clear()
          ..add(opt.id);
      }
    } else {
      // Multi: standard toggle
      if (current.contains(opt.id)) {
        current.remove(opt.id);
      } else {
        current.add(opt.id);
      }
    }
    selections[group.id] = current;
    state = state.copyWith(selectionsByGroupId: selections);
  }
}

/// One controller per item id — auto-dispose when the details screen closes.
final itemConfigurationControllerProvider = StateNotifierProvider.autoDispose
    .family<ItemConfigurationController, ItemConfigurationState, ItemDetail>((ref, item) {
  return ItemConfigurationController(item);
});
