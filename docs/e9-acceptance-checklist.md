# E9 — Acceptance Checklist

Source: `853_..._Product_Backlog.docx` — Epic E9 "حسابات العملاء" — US9.1..US9.4.

## Setup

1. Backend migrated to `e821e6634320` (E9).
2. `flask seed --wipe` marks the seeded customer `0555555555` verified
   and inserts 2 saved addresses.
3. `OTP_SENDER=logging` (default) — codes appear in the Flask console.
4. Flutter app running.

---

## US9.1 — Register with phone + OTP (no email, no password)

- [ ] Open the app fresh → tap the person icon in the home AppBar →
      `/login` screen.
- [ ] Enter a new phone (e.g. `0500000001`) → tap "أرسل الكود" →
      the Flask console prints `[OTP] phone=0500000001 code=NNNNNN`.
- [ ] Enter the 6-digit code on `/verify` → auto-submits on the last
      digit → lands on `/profile` with a fresh customer row.
- [ ] Wrong code → red inline error "الكود غير صحيح".
- [ ] Third wrong attempt in a row → the code row is deleted and the
      user must request a new one.
- [ ] Expired code (>5 min) → "الكود منتهي أو غير موجود — اطلب كوداً جديداً".
- [ ] Rate limit: requesting >5 codes for the same phone in one hour
      → 422 "لقد تم إرسال عدد كبير من الأكواد".

## US9.2 — Log in on subsequent visits + session persists

- [ ] Log out from `/profile` → returns to `/`; person icon shows the
      un-filled outline.
- [ ] Log in again with `0555555555` (grab code from console) → lands
      back on `/profile`.
- [ ] Force-close the app and reopen → still signed in (SharedPreferences
      persisted the token).
- [ ] JWT lifetime is 30 days — leave the app alone for a day, still signed in.
- [ ] Only manual "تسجيل الخروج" clears the session.

## US9.3 — Order history + re-order

- [ ] `/profile/orders` lists past orders newest-first with order
      number, item summary, status pill, total.
- [ ] Tap "التفاصيل" → opens the existing confirmation screen for that order.
- [ ] Tap "أعد الطلب" → cart populates with the exact snapshot lines
      (name, options, quantity, base price) → lands on `/review`. Placing
      the new order re-validates every item/option server-side.
- [ ] History updates when a new order is placed (pull-to-refresh).

## US9.4 — Edit profile (name, addresses)

- [ ] `/profile` shows the phone (read-only, LTR), points balance,
      editable name field.
- [ ] Change the name → "حفظ الاسم" → snackbar confirms → the customer
      row updates + a subsequent order carries the new name.
- [ ] Addresses list shows the 2 seeded ones with "افتراضي" badge on
      the default.
- [ ] "+ إضافة" opens a bottom sheet; enter label + address + optional
      "افتراضي" → save → list refreshes with the new row.
- [ ] Delete an address → row disappears.

## Guest flows still work (regression check)

- [ ] Wipe app data (or use a fresh browser session) → home works
      without login: browse, item details, add to cart, checkout as
      guest by entering phone + name → order goes through and lands on
      the confirmation screen.
- [ ] Loyalty screen still lets a guest type a phone and see the
      balance.
- [ ] Discount preview still works without auth.

## Cross-cutting

- [ ] `GET /api/v1/me` without a token → 401.
- [ ] `POST /api/v1/orders` with a JWT → order.customer_id matches the
      JWT identity, regardless of what's in the request body's phone
      field.
- [ ] Points earned on a delivered order attach to the authed
      customer's account.

---

## Audit pass

For every unchecked box: reproduce, capture actual behaviour, fix,
re-run. Append findings to `docs/e9-audit-report.md`.
