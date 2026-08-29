# E4 — Acceptance Checklist

Every AC from the Word doc's E4 section as a manual test step. Source:
`853_..._Product_Backlog.docx` — Epic E4 "إدارة الطلبات (Admin)".

## Setup

1. Backend migrated to `beb9a36d3739`.
2. `flask seed --wipe` creates 3 sample orders (confirmed, preparing, delivered).
3. Log in to `/admin`.
4. Flutter app running against the backend.

---

## US4.1 — New orders visible immediately + clear indicator

- [ ] Nav bar shows a red badge on الطلبات with the unseen count (starts at 2 after --wipe).
- [ ] `/admin/orders` lists the seeded orders, newest first.
- [ ] The unseen confirmed order has a yellow row + "جديد" badge.
- [ ] Page auto-refreshes every 15 seconds (meta-refresh).
- [ ] Place a new order from the mobile app (any payment method); within 15s
      it appears at the top of the admin list with the "جديد" badge.

## US4.2 — Manual status updates, logical order only, reflected in mobile

- [ ] Open a `confirmed` order. Status card offers exactly:
      **قيد التجهيز**, **ملغى**.
- [ ] Click قيد التجهيز → page reloads, status is preparing. Now offers
      **في الطريق** (or **جاهز للاستلام** for pickup) and **ملغى**.
- [ ] Click في الطريق → offers **تم التسليم** + **ملغى**.
- [ ] Click تم التسليم → status is terminal. Card says "الحالة الحالية
      نهائية — لا يمكن تحديثها".
- [ ] For a pickup order (open the delivered one — or create a new pickup):
      the middle step offers جاهز للاستلام, not في الطريق.
- [ ] With the mobile confirmation screen open on the same order, moving
      the admin status forward appears in the timeline within 15s (or
      immediately on pull-to-refresh).
- [ ] `curl -X POST /admin/orders/<delivered-id>/transition -d "to_status=preparing"` — server refuses (redirect with an Arabic flash; the row stays delivered).

## US4.3 — Full order details visible to admin

- [ ] Order detail page shows: customer name + phone, fulfillment type
      (+ delivery address if applicable), payment method + reference +
      confirmed-at timestamp.
- [ ] Every line shows: name snapshot, image, per-kind option breakdown
      (variant / size / add / remove), quantity, unit price, line total.
- [ ] Totals table shows subtotal, delivery fee (if delivery), grand total.
- [ ] Opening a `confirmed AND admin_seen_at IS NULL` order clears the
      "جديد" badge for that row.
- [ ] Notes section renders only if the order has notes.

## Cross-cutting

- [ ] Filter dropdown works (e.g. show only `preparing`).
- [ ] Nav badge is always in sync with the count of confirmed-and-unseen
      orders (drops as you open new ones).
- [ ] The endpoint `/admin/orders/<id>/transition` is login-required
      (test by logging out and posting → redirect to login).

---

## Audit pass

For every unchecked box: reproduce, capture actual behaviour, fix, re-run.
Append findings to `docs/e4-audit-report.md`.
