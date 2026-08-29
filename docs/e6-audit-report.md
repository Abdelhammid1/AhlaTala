# E6 — Audit Report

Phase 3 pass over every AC in the Word doc's E6 section against the code as
it stands. Source: `853_..._Product_Backlog.docx` — Epic E6 "أكواد الخصم"
— US6.1, US6.2.

---

## Per-story verdicts

| Story | AC | Verdict | Where |
|---|---|---|---|
| **US6.1** | Admin creates codes (percent/fixed, expiry, max uses); can pause | ✅ | `backend/app/admin/discounts.py` + `templates/admin/discounts/*`; `toggle` route flips `is_active`; delete refuses when `uses_count > 0` |
| **US6.2** | Customer enters code at pay-time; total updates; clear errors | ✅ | `backend/app/discounts.py` `preview()` (7 error slugs, all Arabic-messaged); `POST /api/v1/discount-codes/preview`; `DiscountCodeSection` widget wires apply/clear; `_TotalsCard` shows the code line |

---

## In-session verification

Backend, live at `127.0.0.1:5000`:

- **Migration** `0913449a904b_e6_discount_codes` applied cleanly.
- **Preview** `welcome10` on 100 SAR → `{"discount_amount":"10.00"}` ✓
  (case-insensitive normalisation works)
- **Preview** `RAMADAN50` on 50 SAR → `422 below_min_subtotal` with
  Arabic message ✓
- **Preview** `RAMADAN50` on 150 SAR → `{"discount_amount":"50.00"}` ✓
- **Preview** unknown code → `422 not_found` with Arabic message ✓
- **Order create with `discount_code=welcome10`** (subtotal 62):
  - `code_discount:"6.20"`, `discount_amount:"6.20"`, `total:"70.80"` ✓
- **Order create with `WELCOME10` + `points_to_redeem=100`** (customer 0555555555):
  - `points_discount:"10.00"`, `code_discount:"5.20"` (10% of 62−10=52),
  - `discount_amount:"15.20"`, `total:"61.80"` ✓ — no double-dipping
- **`uses_count`** on `WELCOME10` bumped from 0 → 2 after two orders ✓
- **Invalid code in order create** → same `422 not_found` — validation is
  centralised in `discounts.preview()` ✓

Mobile: `flutter analyze` — no issues.

---

## Findings caught during the audit

### 1. Went down a rabbit hole trying to inject settings into `CheckoutController`

Originally reached for a hidden `_settingsForDiscount` shim provider inside
the controller so `applyDiscountCode(code, subtotal)` didn't need a
`pointsDiscount` argument. It landed as a mess of alias providers and even
a mid-file `import`. Reverted to the boring signature — widget passes
`pointsDiscount` in, computed from settings that the widget already
watches. Kept the module cycle-free.

### 2. `discount_amount` = `points_discount + code_discount` is now
denormalised

E5 wrote to `discount_amount`; E6 splits into two components AND keeps
`discount_amount` as the sum for backwards compatibility. Callers should
prefer the split fields; the sum field is convenience for existing
reports (E4 admin views etc.). Documented in the Order model docstring.

### 3. Percent code applies to (subtotal − points_discount)

Deliberate choice recorded in the plan: prevents effective double-
discounting. A 10% code on a 100 SAR cart with a 10 SAR points redeem
gives 9 SAR, not 10. Verified by API round-trip in the smoke test above.

### 4. No per-customer usage cap

`max_uses` is global. A returning customer can burn a code many times
(as long as global cap holds). E9 auth + a new `discount_code_uses`
table (customer_id, code_id, timestamps) would be the clean fix; not
in scope for E6.

### 5. Expired / inactive / exhausted codes are all `422`s

Not `404`s. All rejections come back as `422 error_slug` so the mobile
side can render a specific message without pattern-matching on status
codes.

### 6. `delete` refuses when `uses_count > 0`; deactivate is the escape hatch

Prevents dangling FKs on historical orders whose `discount_code_id`
points at deleted codes. Because `orders.discount_code_id` uses
`ON DELETE SET NULL`, deletion doesn't actually break anything, but the
receipt would then say "code (removed)" — usually not what the operator
wants. Recorded here so the refuse-message doesn't surprise anyone.

None of these are gaps against the Word doc.

---

## Not verified in-session (needs a running Flutter session)

- Discount widget's success chip + X-clear flow.
- Confirmation-screen chip + totals line for a code-discounted order.
- Auto-uppercase behaviour of the admin form's `code` field.

## Follow-ups (small, out of the E6 critical path)

- Unit tests for `discounts.preview` — every error slug + happy paths.
- Show the discount value in the admin form's help text as it changes
  (percent vs fixed).
- Per-customer usage caps once E9 (auth) lands.
- Bulk-generate + export codes (CSV) for a campaign.
- Push notifications on newly-published codes (E8).
