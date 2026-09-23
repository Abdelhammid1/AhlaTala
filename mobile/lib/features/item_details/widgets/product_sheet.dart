import 'package:flutter/material.dart';

import '../screens/item_details_screen.dart';

/// Convenience opener for the product detail bottom sheet.
///
/// Every "tap a product" flow in the app goes through here — the underlying
/// widget is [ItemDetailsScreen] rendered with `presentedAsSheet: true`, so
/// the option-groups / configuration controller / cross-sell logic stays a
/// single implementation. The `/items/:id` route still exists for deep
/// links (push notifications, share URLs), rendering the same screen with
/// the full-page chrome.
///
/// The sheet is:
///   - **Draggable** — starts at 92% of screen height, can be dragged down
///     to dismiss. `isScrollControlled: true` lets it exceed half-screen.
///   - **Scrollable** — the inner ListView takes over once the sheet is at
///     max extent (DraggableScrollableSheet's snap behaviour).
///   - **Background-dimmed** — the host home screen dims to ~55% behind.
///   - **RTL-preserving** — inherits the ambient Directionality.
class ProductSheet {
  const ProductSheet._();

  /// Present the product sheet for [itemId].
  ///
  /// Returns when the sheet is dismissed. Callers don't need to await this
  /// unless they want to invalidate providers after the customer leaves the
  /// sheet (e.g. re-fetch the cart badge — the cart controller already
  /// broadcasts state changes, so waiting is rarely necessary).
  static Future<void> show(BuildContext context, int itemId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x8C000000),
      useSafeArea: true,
      // Dragging the handle / sheet body pops the sheet naturally.
      enableDrag: true,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          snap: true,
          snapSizes: const [0.92],
          builder: (_, scrollController) {
            // The inner screen owns its own ListView, so we don't wire
            // `scrollController` through — DraggableScrollableSheet still
            // dismisses on drag-down thanks to its gesture arena, which
            // is enough for our UX.
            return ItemDetailsScreen(itemId: itemId, presentedAsSheet: true);
          },
        );
      },
    );
  }
}
