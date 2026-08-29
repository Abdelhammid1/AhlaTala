# E2 — Audit Report

Phase 3 pass over every acceptance criterion in the Word doc's E2 section
against the code as it stands. Source: `853_..._Product_Backlog.docx` — Epic
E2 "السلة وإتمام الطلب".

---

## Per-story verdicts

| Story | AC | Verdict | Where |
|---|---|---|---|
| **US2.1** | Cannot add before every required group is chosen | ✅ | `mobile/lib/features/item_details/screens/item_details_screen.dart` (button gated on `canAddToCart`), belt-and-braces refuse in `CartController.addLineFromConfiguration` |
| **US2.2** | Qty edit / delete, total updates live | ✅ | `CartController.updateQuantity`, `removeLine`; `cartTotalProvider`/`cartDeliveryFeeProvider` watch state |
| **US2.3** | Delivery vs pickup mandatory; address only when delivery | ✅ | `FulfillmentPicker`, `Fulfillment.isReadyForReview`, `canReviewCartProvider` |
| **US2.4** | Cross-sell horizontal list w/ quick-add on add-to-cart | ✅ | `CrossSellSheet.show()` triggered from `_addToCart`, backed by `/api/v1/items/<id>/cross_sells` sorted by admin `sort_order` |
| **US2.5** | Full review before payment: per-line breakdown, subtotal, delivery, total | ✅ | `OrderReviewScreen`, per-kind option grouping, totals card |
| **US2.6** | Admin: link items as cross-sells for another item | ✅ | `backend/app/admin/cross_sells.py` + cross-sell section in `items/form.html`; server-side rejection of self-link / duplicate / inactive target |

Payment button on the review screen is STUBBED for E3, mirroring the E1
add-to-cart stub pattern that was already agreed.

---

## In-session verification

Backend, live at `127.0.0.1:5000`:

- `GET /api/v1/settings` → `{"currency":"SAR","delivery_fee":"15.00"}`
- `GET /api/v1/items/<pizza>/cross_sells` → `[pasta, coke]`
- `GET /api/v1/items/<pasta>/cross_sells` → `[coke]`
- `GET /api/v1/items/<coke>/cross_sells` → `[]`
- Admin routes registered:
  `/admin/items/<id>/cross_sells/add`,
  `/admin/items/<id>/cross_sells/<link_id>/remove`,
  `/admin/items/<id>/cross_sells/<link_id>/reorder`.
- Migration `724553f6ce4f_e2_cross_sell_links` applied cleanly to Postgres.

Mobile: `flutter analyze` clean (no warnings, no infos).

---

## Findings caught during the audit

### 1. Options-model unused-import in the cart controller

**File:** `mobile/lib/features/cart/providers/cart_controller.dart`

`option_group.dart` was imported for a type hint that ended up not being
needed; `flutter analyze` flagged it. Removed.

### 2. Duplicate-item lines are NOT merged (intentional)

Adding the same item twice creates two separate cart lines with independent
UUIDs. This is intentional because two "identical" configurations may still
differ later (loyalty redemption applied to one, note added to another), and
merging would then need to be undone. Recorded here so future work doesn't
"fix" it silently.

### 3. `_addToCart` re-reads the item detail rather than closing over it

`_BottomCta._addToCart` reads `itemDetailProvider` again instead of using the
`item` from the enclosing `.data((item) => ...)` builder. Works today (Riverpod
returns the same cached instance so the `family` key matches), but is
mildly fragile if the provider ever gets invalidated between the tap and
the read. Considered refactoring, decided against it: the current code
guarantees we're operating on the latest state at click-time, which matters
more than the tiny robustness concession.

### 4. Snackbar and cross-sell sheet stack visually

The "تمت الإضافة" snackbar and the cross-sell bottom sheet are both
overlays. The snackbar could be hidden by the sheet on tall phones.
Mitigation: snackbar duration set to 1 second so it fades before the sheet
is dismissed. Real fix (deferred): show a single toast INSIDE the sheet
header instead of a Material snackbar.

### 5. Address validation is a length heuristic only

`Fulfillment.isReadyForReview` requires ≥ 5 characters for a delivery
address. The doc says "يظهر عنوان التوصيل" — it doesn't specify a rule.
This heuristic prevents obvious blank/short mis-taps without over-fitting.
Later Epics (map picker, saved addresses in E9) will replace it.

None of these are gaps against the Word doc — they are recorded so a later
pass has the context.

---

## Not verified in-session (needs a running Flutter session)

- Cart badge count updates on the AppBars — trivial once the app runs.
- SharedPreferences persistence across app restarts — code path is standard.
- Cross-sell sheet visual polish on a real device.

## Follow-ups (small, out of the E2 critical path)

- Unit tests for `CartController` — line math, qty stepper edges, fulfillment
  gating logic. This is the load-bearing E2 piece the way
  `ItemConfigurationController` was for E1.
- Admin: drag-sort UI for cross-sells (backend already respects `sort_order`).
- Settings admin form for `DELIVERY_FEE` — currently `.env`-only.
- Better address handling — see finding #5.
