import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/prefs.dart';
import '../../../data/models/cart_line.dart';
import '../../../data/models/item.dart';
import '../../item_details/controllers/item_configuration_controller.dart';
import '../models/fulfillment.dart';
import 'settings_provider.dart';

const _kCartLinesKey = 'cart.lines.v1';
const _kFulfillmentKey = 'cart.fulfillment.v1';

class CartState {
  final List<CartLine> lines;
  final Fulfillment fulfillment;

  const CartState({required this.lines, required this.fulfillment});

  const CartState.empty()
      : lines = const [],
        fulfillment = const Fulfillment.none();

  CartState copyWith({List<CartLine>? lines, Fulfillment? fulfillment}) =>
      CartState(
        lines: lines ?? this.lines,
        fulfillment: fulfillment ?? this.fulfillment,
      );

  int get itemsCount => lines.fold(0, (acc, l) => acc + l.quantity);

  double get subtotal =>
      lines.fold<double>(0.0, (acc, l) => acc + l.linePrice);

  bool get isEmpty => lines.isEmpty;
}

class CartController extends StateNotifier<CartState> {
  CartController(this._prefs, CartState initial) : super(initial);

  final SharedPreferences _prefs;

  // ---- mutations ----

  /// Add a configured line from the current item-details configuration state.
  /// Snapshots names/prices from the item detail so admin changes don't affect
  /// existing cart lines. Refuses when required groups aren't satisfied — the
  /// caller (item details screen) already gates on this, so this is a belt-
  /// and-braces safeguard.
  bool addLineFromConfiguration(ItemConfigurationState cfg) {
    if (!cfg.canAddToCart) return false;

    final selections = <CartLineSelection>[];
    for (final g in cfg.item.optionGroups) {
      final selectedIds = cfg.selectionsByGroupId[g.id] ?? const <int>{};
      if (selectedIds.isEmpty) continue;
      for (final o in g.options) {
        if (!selectedIds.contains(o.id)) continue;
        selections.add(CartLineSelection(
          groupId: g.id,
          groupNameAr: g.nameAr,
          groupKind: g.kind.name,
          optionId: o.id,
          optionNameAr: o.nameAr,
          priceDelta: o.priceDelta,
        ));
      }
    }

    final line = CartLine.newLine(
      itemId: cfg.item.id,
      // Snapshot the *displayed* name so a chosen variant is preserved
      nameAr: cfg.displayName,
      imageUrl: cfg.displayImageUrl,
      basePrice: cfg.item.basePrice,
      selections: selections,
    );

    state = state.copyWith(lines: [...state.lines, line]);
    _persist();
    return true;
  }

  /// E9 — push a fully-formed line from an order-history snapshot. Bypasses
  /// the item-configuration controller because everything (name, image,
  /// base_price, selections, quantity) is already known. The server re-
  /// validates on the next order-create call, so this is safe.
  void addSnapshot({
    required int itemId,
    required String nameAr,
    String? imageUrl,
    required double basePrice,
    required int quantity,
    required List<CartLineSelection> selections,
  }) {
    final line = CartLine.newLine(
      itemId: itemId,
      nameAr: nameAr,
      imageUrl: imageUrl,
      basePrice: basePrice,
      selections: selections,
      quantity: quantity,
    );
    state = state.copyWith(lines: [...state.lines, line]);
    _persist();
  }

  /// Add an item that has NO option groups (e.g. a drink). Used by the
  /// cross-sell quick-add path.
  bool addBareItem(ItemDetail item) {
    if (item.optionGroups.any((g) => g.isRequired)) return false;
    final line = CartLine.newLine(
      itemId: item.id,
      nameAr: item.nameAr,
      imageUrl: item.imageUrl,
      basePrice: item.basePrice,
      selections: const [],
    );
    state = state.copyWith(lines: [...state.lines, line]);
    _persist();
    return true;
  }

  void updateQuantity(String lineId, int qty) {
    if (qty < 1) {
      removeLine(lineId);
      return;
    }
    state = state.copyWith(
      lines: [
        for (final l in state.lines)
          if (l.id == lineId) l.copyWith(quantity: qty) else l,
      ],
    );
    _persist();
  }

  void removeLine(String lineId) {
    state = state.copyWith(lines: state.lines.where((l) => l.id != lineId).toList());
    _persist();
  }

  void setFulfillment(FulfillmentType type, {String? address}) {
    state = state.copyWith(fulfillment: Fulfillment(type: type, address: address));
    _persist();
  }

  void clear() {
    state = const CartState.empty();
    _persist();
  }

  // ---- persistence ----

  Future<void> _persist() async {
    await _prefs.setString(
      _kCartLinesKey,
      jsonEncode(state.lines.map((l) => l.toJson()).toList()),
    );
    await _prefs.setString(_kFulfillmentKey, jsonEncode(state.fulfillment.toJson()));
  }
}

// -------------------------------------------------------------------

CartState _restoreState(SharedPreferences prefs) {
  final rawLines = prefs.getString(_kCartLinesKey);
  final rawFul = prefs.getString(_kFulfillmentKey);
  final lines = <CartLine>[];
  if (rawLines != null && rawLines.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawLines);
      if (decoded is List) {
        for (final e in decoded) {
          lines.add(CartLine.fromJson(e as Map<String, dynamic>));
        }
      }
    } catch (_) {/* if schema changed underneath us, start fresh */}
  }
  Fulfillment ful = const Fulfillment.none();
  if (rawFul != null && rawFul.isNotEmpty) {
    try {
      ful = Fulfillment.fromJson(jsonDecode(rawFul) as Map<String, dynamic>);
    } catch (_) {}
  }
  return CartState(lines: lines, fulfillment: ful);
}

final cartControllerProvider =
    StateNotifierProvider<CartController, CartState>((ref) {
  // Synchronous read from the app-wide prefs provider — resolved in main().
  final prefs = ref.watch(sharedPrefsProvider);
  return CartController(prefs, _restoreState(prefs));
});

// -------------------------------------------------------------------
// Derived: total price (depends on delivery fee from settings).

final cartTotalProvider = Provider<double>((ref) {
  final state = ref.watch(cartControllerProvider);
  final settings = ref.watch(settingsProvider).maybeWhen(
        data: (s) => s,
        orElse: () => AppSettings.fallback(),
      );
  final delivery =
      state.fulfillment.type == FulfillmentType.delivery ? settings.deliveryFee : 0.0;
  return state.subtotal + delivery;
});

final cartDeliveryFeeProvider = Provider<double>((ref) {
  final state = ref.watch(cartControllerProvider);
  if (state.fulfillment.type != FulfillmentType.delivery) return 0.0;
  final settings = ref.watch(settingsProvider).maybeWhen(
        data: (s) => s,
        orElse: () => AppSettings.fallback(),
      );
  return settings.deliveryFee;
});

/// Can the user move to the review screen? Non-empty cart + fulfillment
/// picked + delivery address filled (when applicable).
final canReviewCartProvider = Provider<bool>((ref) {
  final state = ref.watch(cartControllerProvider);
  return !state.isEmpty && state.fulfillment.isReadyForReview;
});
