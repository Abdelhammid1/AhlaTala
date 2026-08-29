# E8 — Acceptance Checklist

Source: `853_..._Product_Backlog.docx` — Epic E8 "الإشعارات" — US8.1, US8.2.

## Setup

1. Backend migrated to `486a0a541b1d` (E8).
2. `flask seed --wipe` inserts a welcome broadcast to all seeded
   customers (currently 2 customers).
3. Log in to `/admin`.
4. Flutter app running; on first launch open "نقاطي" and enter
   `0555555555` once so the app remembers the phone.

---

## US8.1 — Admin sends to all or a segment

- [ ] `/admin/notifications` shows the seeded welcome broadcast, target
      "الجميع", delivered count = 2.
- [ ] "+ إشعار جديد" opens the compose form.
- [ ] Sending with target `الجميع` fires to every customer;
      `delivered_count` matches DB row count.
- [ ] Target `عملاء لم يطلبوا منذ 30 يوم` fires only to customers with
      zero orders OR whose latest order is 30+ days old (on a fresh
      seed everyone has recent orders → 0 sent; a flash warns "لا يوجد
      عملاء في هذه الشريحة").
- [ ] Target `عملاء طلبوا مسبقاً` fires only to customers with at
      least one linked order.
- [ ] Detail page for a notification lists every recipient with a
      "قُرئ / جديد" badge that updates as customers read.

## US8.2 — Customer receives push while app closed; opens app on tap

- [ ] Bell icon in the categories AppBar shows a badge with the
      customer's unread count.
- [ ] Tap the bell → inbox screen renders the welcome message with a
      distinctive unread background.
- [ ] Tap the message → background turns white, unread count drops,
      badge on the AppBar clears.
- [ ] With the app in foreground and the poller running, admin sends
      a new notification → within ~20s an OS-level toast pops up (via
      `flutter_local_notifications`), the bell badge increments, and
      the notification appears in the inbox.
- [ ] Pull-to-refresh on the inbox re-fetches deliveries.
- [ ] Truly-out-of-process push (app force-closed) — **deferred to
      the Firebase Epic**. The `POST /api/v1/devices/register` +
      `DeviceToken` table + `FcmSender` stub are ready to receive the
      real integration.

## Cross-cutting

- [ ] `GET /api/v1/customers/lookup?phone=X` returns
      `unread_notifications: N`.
- [ ] The saved-phone survives an app restart (SharedPreferences).
- [ ] Placing an order also saves the phone (auto-populates the
      inbox for a first-time customer without them typing it twice).

---

## Audit pass

For every unchecked box: reproduce, capture actual behaviour, fix,
re-run. Append findings to `docs/e8-audit-report.md`.
