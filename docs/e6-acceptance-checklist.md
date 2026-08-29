# E6 — Acceptance Checklist

Source: `853_..._Product_Backlog.docx` — Epic E6 "أكواد الخصم" — US6.1, US6.2.

## Setup

1. Backend migrated to `0913449a904b` (E6).
2. `flask seed --wipe` inserts `WELCOME10` (10% off, unlimited) and
   `RAMADAN50` (50 SAR off, min 100 SAR, expires next year, max 100 uses).
3. Log in to `/admin`.
4. Flutter app running.

---

## US6.1 — Admin creates code (percent or fixed, expiry, max uses, pause)

- [ ] `/admin/discounts` shows both seeded codes with their kind / value /
      uses / expiry / status.
- [ ] "+ كود جديد" opens the form. Create a percent code (`TEST20`, 20%).
- [ ] Create a fixed-amount code (`FIXED30`, 30 SAR) with expiry set to
      yesterday. It saves and shows a "منتهي" badge.
- [ ] Create a code with `max_uses = 3`. Placing 3 orders with it flips
      preview from `200` to `422 exhausted`.
- [ ] "إيقاف" flips `is_active` — preview returns `422 inactive` on the
      next call. Reactivate to restore.
- [ ] Deleting a code with `uses_count > 0` is refused with an Arabic
      warning; you must deactivate instead.
- [ ] Uniqueness enforced: creating another `WELCOME10` shows
      "هذا الكود موجود بالفعل".
- [ ] Codes are auto-uppercased: type `test-code` → saved as `TEST-CODE`.

## US6.2 — Customer enters code at checkout; total updates; errors are clear

- [ ] Fill the review form, tap "تطبيق" for `welcome10` → green chip
      "الكود WELCOME10 — خصم X ريال"; total drops by the discount.
- [ ] Type `NOPE` → red error "الكود غير صحيح" under the field.
- [ ] Type an expired code → "انتهت صلاحية الكود".
- [ ] Type `RAMADAN50` on a cart under 100 SAR → "الحد الأدنى للطلب لم
      يتم بلوغه".
- [ ] Type an inactive code → "الكود موقوف مؤقتاً".
- [ ] Tap X on an applied code → discount cleared, total restored.
- [ ] Place the order — response reflects `code_discount` and
      `discount_code`; `uses_count` on the DB row increments by 1.
- [ ] Confirmation screen shows the code chip + a "خصم كود (CODE)" line
      in the totals card.

## Cross-cutting

- [ ] `/api/v1/discount-codes/preview` responds 422 with a stable
      `error` slug + Arabic `message` on every rejection path.
- [ ] Percent code applied AFTER points redemption:
      `WELCOME10` + 100 pts on a 100 SAR cart →
      points_discount = 10, code_discount = 9 (10% of 90),
      total = 100 + 15 − 19 = 96.
- [ ] Case-insensitive: `welcome10` == `WELCOME10`.

---

## Audit pass

For every unchecked box: reproduce, capture the actual behaviour, fix,
re-run. Append findings to `docs/e6-audit-report.md`.
