# E3 — Acceptance Checklist

Every acceptance criterion in the Word doc's E3 section as a manual test step.
Source: `853_..._Product_Backlog.docx` — Epic E3 "الدفع" — US3.1..US3.3.

## Setup

1. Backend up, DB migrated to `05abfb5056fd` (E3).
2. Flutter app running against that backend.
3. Cart has at least one line and a fulfillment picked (any).

---

## US3.1 — Cash on delivery, immediate confirmation

- [ ] Review screen shows "الدفع كاش عند الاستلام" as a selectable option.
- [ ] Selecting it changes the CTA to "أكد الطلب  •  {total} ريال".
- [ ] Tapping the CTA creates the order (backend returns
      `payment.status='confirmed'`), the cart is cleared, and the app lands
      on the confirmation screen with an `AT-YYYY-NNNNNN` order number.

## US3.2 — Apple Pay via Saudi gateway; confirm only after success

- [ ] Selecting "Apple Pay — بوابة الدفع السعودية" changes the CTA to
      "ادفع الآن  •  {total} ريال".
- [ ] Tapping the CTA creates the order (status=`created`) and pushes the
      gateway stub screen.
- [ ] "محاكاة نجاح الدفع" POSTs to `/orders/{id}/confirm`, cart clears,
      confirmation screen shows.
- [ ] "محاكاة فشل الدفع" POSTs to `/orders/{id}/fail`, returns to review
      with a red snackbar, cart still populated.

## US3.3 — Instant confirmation screen with number + details

- [ ] Confirmation screen shows: green check, order number, status "مؤكد",
      fulfillment recap (address for delivery, "استلام من الفرع" otherwise),
      per-line breakdown with chosen options, subtotal + delivery-fee +
      total.
- [ ] "متابعة التصفح" returns to `/`.

## Server-side price authority

- [ ] Trying to POST an order with a nonexistent `option_id` → 422.
- [ ] Trying to POST with a missing required option group → 422.
- [ ] Prices returned by the server never come from the client (base_price +
      deltas are computed from active DB rows).

## Cross-cutting

- [ ] CTA is disabled with a hint until: name ≥ 2 chars, phone ≥ 4 chars,
      and a payment method is picked.
- [ ] Order number format: `AT-YYYY-000001`.
- [ ] `/api/v1/orders/{id}/confirm` is idempotent (calling twice keeps status
      confirmed, doesn't error).

---

## Audit pass

For every unchecked box: reproduce, capture actual behaviour, fix, re-run.
Append findings to `docs/e3-audit-report.md`.
