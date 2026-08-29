# E5 — Audit Report

Phase 3 pass over every AC in the Word doc's E5 section against the code as
it stands. Source: `853_..._Product_Backlog.docx` — Epic E5 "نظام نقاط
الولاء" — US5.1 through US5.4.

---

## Per-story verdicts

| Story | AC | Verdict | Where |
|---|---|---|---|
| **US5.1** | Auto accrual on completed order, per admin rule | ✅ | `app/observers.py` `_award_on_delivered` (before_flush) → `app/loyalty.py` `award()` — reads `LoyaltySettings`, writes ledger, idempotent via ledger check |
| **US5.2** | Balance visible in the app | ✅ | `LoyaltyScreen` (phone lookup) + `/api/v1/customers/lookup` + `/api/v1/customers/<id>/ledger`; entry point is the stars icon in the categories AppBar |
| **US5.3** | Redemption at checkout when balance is sufficient | ✅ | `RedeemPointsSection` on review; `CheckoutController.setPointsToRedeem` + body field; server-side `preview_redemption` clamps and `redeem` writes the ledger + adjusts totals |
| **US5.4** | Admin sets rates | ✅ | `/admin/loyalty` — form for `points_per_riyal`, `riyal_per_point`, `min_redeem_points`; nav tab; values flow through `LoyaltySettings.instance()` |

---

## In-session verification

Backend, live at `127.0.0.1:5000`:

- **Settings endpoint** (extended):
  ```
  {"currency":"SAR","delivery_fee":"15.00","min_redeem_points":100,"points_per_riyal":"1.000","riyal_per_point":"0.100"}
  ```
- **Customer lookup**: `GET /api/v1/customers/lookup?phone=0555555555` →
  `{"customer_id":1,"name":"عميل جديد","phone":"0555555555","points_balance":250}` ✓
- **Order create with `points_to_redeem=100`** (subtotal 62):
  - `discount_amount: 10.00`, `total: 67.00` (62 + 15 − 10) ✓
  - `points_redeemed: 100`, `customer_id: 1` ✓
  - Balance dropped 250 → 150 ✓
- **Award on delivered** (via direct model transitions):
  - `order.points_earned = 62` (int(62 × 1.0)) ✓
  - Balance jumped 150 → 212 ✓
- **Idempotency**: second flip back into `delivered` did NOT re-award — balance still 212 ✓
- **Migration** `5532110864f7_e5_loyalty_tables_order_columns` applied cleanly.

Mobile: `flutter analyze` — no issues.

---

## Findings caught during the audit

### 1. Missing `Order.customer` relationship crashed the delivered-flip observer

**File:** `backend/app/models/order.py`

The observer read `obj.customer` to route the award, but `Order` only had
`customer_id`. First delivery flip after redemption raised
`AttributeError: 'Order' object has no attribute 'customer'`. Fixed by
adding `customer = db.relationship("Customer")` on `Order`. Retested — the
transition + award path now works end-to-end and idempotency holds.

### 2. Loyalty look-up API is unauthenticated

**Files:** `backend/app/api/customers.py`, `settings.py`

Matches E1–E4's guest posture (no auth anywhere yet). E9 will layer
session auth on top and gate `/customers/lookup` behind it — with today's
model anyone who knows a phone number can read that number's balance and
ledger. Recorded in the E5 scope-boundary paragraph of the plan.

### 3. Review-screen discount preview is UI-only; server is the truth

**File:** `mobile/lib/features/cart/screens/order_review_screen.dart` `_TotalsCard`

The preview multiplies `pointsToRedeem × riyalPerPoint` for a live number.
The server clamps and re-computes, so if a race let the user submit more
points than they now have, the final order's `points_redeemed` and
`discount_amount` are the authoritative values — the confirmation screen
shows what actually happened. Documented in `_TotalsCard`'s docstring.

### 4. `points_per_riyal` uses `int(floor(...))`

Chosen for predictability. `subtotal 10.50 × 1.5 = 15.75` → 15 points
awarded, not 16. Same convention across the loyalty code (`preview_redemption`,
`award`).

### 5. Cancelled / failed orders never award

The observer only fires on `status == OrderStatus.delivered`. Cancel or
fail an order and no ledger row is written. Correct — the doc says
"طلب مكتمل" (completed order).

### 6. `_line` helper leftover killed the analyze

An unused `_line` method survived the extraction of `_TotalsCard`.
`flutter analyze` failed on `unused_element`. Removed. Clean.

---

## Not verified in-session (needs a running Flutter session)

- Redeem widget visibility gates on balance / min_redeem_points.
- "Max" button snaps to the min-increment.
- Confirmation-screen loyalty chips: "استخدمت / لقد كسبت / ستحصل على".
- LoyaltyScreen ledger listing.

## Follow-ups (small, out of the E5 critical path)

- Unit tests for `loyalty.preview_redemption` — clamp order matters
  (min → balance → subtotal cap → snap-to-step).
- Persist the last-used phone in SharedPreferences so LoyaltyScreen
  pre-fills.
- Loyalty tiers (silver/gold/platinum) once shop asks.
- E8 push on `earned` ledger writes so the customer learns the moment
  their order is delivered.
- E9 will re-key the look-up endpoint behind auth (see finding #2).
