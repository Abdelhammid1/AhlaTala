# E5 — Acceptance Checklist

Source: `853_..._Product_Backlog.docx` — Epic E5 "نظام نقاط الولاء" — US5.1–US5.4.

## Setup

1. Backend migrated to `5532110864f7` (E5).
2. `flask seed --wipe` seeds the singleton `loyalty_settings` (1 pt/riyal,
   0.10 riyal/pt, min 100) and a customer at `0555555555` with **250** points.
3. Log in to `/admin`; app running.

---

## US5.1 — Auto accrual on completed order, per admin rule

- [ ] Place an order via the mobile app using phone `0555555555` (or any
      phone; the customer row auto-upserts).
- [ ] Advance the order through statuses in `/admin/orders/<id>` all the way
      to **تم التسليم**.
- [ ] Customer's balance in `/admin/customers/<id>` increases by
      `int(order.subtotal × points_per_riyal)`; a `earned` row is appended
      to the ledger with the order reference.
- [ ] Force-flip the order back to preparing and to delivered again
      (via a manual DB tweak, since the workflow won't allow it) — balance
      does NOT double (idempotent).
- [ ] Cancel a not-yet-delivered order — no earn ledger row appears.

## US5.2 — Balance visible in the app

- [ ] Tap the stars icon in the categories AppBar → لوحة "نقاطي" opens.
- [ ] Enter `0555555555` → balance card shows 250 (before any activity).
- [ ] The ledger below lists any earn/redeem entries with the correct sign
      and reason.

## US5.3 — Redemption at checkout

- [ ] Fill the review form with phone `0555555555`. When the phone hits ≥4
      chars, the "استخدام نقاط الولاء" section appears.
- [ ] Balance shown matches the API (250).
- [ ] Stepper snaps in 100-pt increments (min_redeem_points).
- [ ] Discount preview updates live (`points × riyal_per_point`).
- [ ] "الحد الأقصى" caps at whichever is smaller: balance or the
      point-equivalent of the current subtotal.
- [ ] Placing the order returns the actual applied `points_redeemed` and
      `discount_amount` from the server; the confirmation screen shows
      "استخدمت X نقطة (خصم Y ريال)".
- [ ] Server clamps mismatched requests: send `points_to_redeem=99999` for
      a small cart and confirm the response's `points_redeemed` is capped
      to the affordable / balance-limited number.

## US5.4 — Admin sets rates

- [ ] `/admin/loyalty` shows the three fields with current values.
- [ ] Change `points_per_riyal` to `0.5` → a new order's earned points
      (once delivered) become `int(subtotal × 0.5)`.
- [ ] Change `riyal_per_point` to `0.25` → mobile review shows a bigger
      discount for the same point count (settings API is re-fetched).
- [ ] Change `min_redeem_points` to `200` → mobile redemption section
      hides when balance < 200.

## Cross-cutting

- [ ] `GET /api/v1/settings` returns loyalty fields alongside the E2 ones.
- [ ] `GET /api/v1/customers/lookup?phone=unknown` returns 404 cleanly.
- [ ] Points math uses `floor` — with `points_per_riyal=1.5` and a
      subtotal of 10.50, delivered awards 15 (not 16).

---

## Audit pass

For every unchecked box: reproduce, capture actual behaviour, fix, re-run.
Append findings to `docs/e5-audit-report.md`.
