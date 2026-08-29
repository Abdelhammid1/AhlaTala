# E3 — Audit Report

Phase 3 pass over every acceptance criterion in the Word doc's E3 section
against the code as it stands. Source: `853_..._Product_Backlog.docx` — Epic
E3 "الدفع" — US3.1 through US3.3.

---

## Per-story verdicts

| Story | AC | Verdict | Where |
|---|---|---|---|
| **US3.1** | Cash option visible, order confirmed immediately, no gateway | ✅ | `backend/app/payments/cash.py` marks order confirmed synchronously; mobile `_submit` in `OrderReviewScreen` navigates straight to the confirmation screen when `payment.status='confirmed'` |
| **US3.2** | Apple Pay → Saudi gateway → confirm only after success | ✅ (via **stub gateway**) | `StubGatewayProvider` returns `redirect_url`; mobile pushes `GatewayStubScreen`; success posts to `/orders/<id>/confirm`; failure posts to `/orders/<id>/fail` — same shape a real Moyasar/HyperPay/Tap SDK will drop into |
| **US3.3** | Confirmation screen with order number + details | ✅ | `OrderConfirmationScreen` reads `GET /api/v1/orders/<id>`; shows `order_number` (format `AT-YYYY-NNNNNN`), fulfillment recap, per-line breakdown, totals |

---

## In-session verification

Backend, live at `127.0.0.1:5000`:

- **Cash flow:** `POST /api/v1/orders` with `payment_method=cash`, 1 pizza × 2, delivery. Response:
  - `order_number: AT-2026-000001`
  - `status: confirmed`
  - subtotal `124.00` = (base 30 + variant +10 + size +22) × 2 ✅
  - delivery_fee `15.00` + total `139.00` ✅
  - `payment.status: confirmed`, `reference: cash-1` ✅
- **Gateway stub flow:** `POST /api/v1/orders` with `payment_method=apple_pay`, pickup. Response:
  - `order_number: AT-2026-000002`
  - `status: created`
  - `payment.status: redirect`, `redirect_url: http://127.0.0.1:5000/api/v1/payments/stub/2` ✅
  - `POST /api/v1/orders/2/confirm` with `{"reference":"stub-txn-abc"}` → `status=confirmed`, `payment_reference=stub-txn-abc` ✅
- **Validation:** POST with a too-short `customer_phone` → **422** ✅
- All 5 new routes registered (POST /orders, GET /orders/<id>, /confirm, /fail, GET /payments/stub/<id>).
- Migration `05abfb5056fd_e3_orders` applied cleanly.

Mobile: `flutter analyze` — no issues.

---

## Findings caught during the audit

### 1. Reset a bungled `Write` that clobbered `app/api/__init__.py`

**File:** `backend/app/api/__init__.py`

I called Write with edit-style parameters and the resulting file overwrote
the blueprint bootstrap with the schemas payload. The dev server tried to
reload and crashed. Fix: restored the correct one-liner `__init__.py` that
just registers routes, and put schemas in `order_schemas.py` where they
belonged. Server restarted; all endpoints came back green.

Lesson recorded here so a future pass sees why the E3 patchset has one
"restored" file in the diff.

### 2. Two-writes-per-order for `order_number`

**File:** `backend/app/observers.py`

`order_number` is set in an `after_insert` observer that issues an extra
UPDATE. Adds one write per order — negligible at MVP volume. Cleaner
alternatives (Postgres trigger, computed column, or a pre-fetch of the
sequence) can replace this later without any surface-area change.

### 3. Checkout state persists across orders

**File:** `mobile/lib/features/checkout/controllers/checkout_controller.dart`

Only the cash path calls `CheckoutController.reset()`. After a successful
gateway payment, `paymentMethod`, `customerName`, and `customerPhone`
remain in state. This is arguably a feature (a returning customer doesn't
re-type their name and phone), but it should be an explicit decision — I've
left it as-is for now. If we want it cleared, add a `.reset()` at
`OrderConfirmationScreen.initState()`.

### 4. Failed-then-confirmed order path is closed

**File:** `backend/app/api/orders.py` — `confirm_order`

If `/fail` was called first, `/confirm` returns 409. Real gateways
occasionally deliver a "confirmed" webhook after we've already given up
locally. For the stub this is fine; when a real gateway lands, revisit
whether the webhook should be allowed to promote a `failed` order to
`confirmed`.

### 5. Cash confirmation writes both here and in the model

`CashProvider.start` sets `order.confirmed_at` explicitly. The `/confirm`
endpoint does the same for gateway-callback orders. Two code paths that
both do the "flip to confirmed" work. Not a bug (they run in different
control flows), but if a third payment method appears, factor a shared
`_mark_confirmed(order, reference)` helper.

None of these are gaps against the Word doc — they are recorded so future
work has context.

---

## Not verified in-session (needs a running Flutter session)

- Full cash → confirmation navigation in the app.
- Full gateway-stub → confirm → confirmation navigation in the app.
- Cart clearing on entry to the confirmation screen.
- Missing-name / missing-payment CTA disable + hint text.

## Follow-ups (small, out of the E3 critical path)

- Unit tests for `CashProvider.start` and the price-recompute path in
  `create_order` — the money-authority code is the highest-value target
  for tests right now.
- When a real Saudi payment gateway is picked, replace
  `StubGatewayProvider` in `backend/app/payments/registry.py` and swap
  `GatewayStubScreen` for the SDK's checkout — nothing else needs to move.
- E4 will build the admin views on top of the `orders` table.
