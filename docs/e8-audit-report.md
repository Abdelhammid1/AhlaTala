# E8 — Audit Report

Phase 3 pass over every AC in the Word doc's E8 section against the code as
it stands. Source: `853_..._Product_Backlog.docx` — Epic E8 "الإشعارات"
— US8.1, US8.2.

---

## Per-story verdicts

| Story | AC | Verdict | Where |
|---|---|---|---|
| **US8.1** | Admin sends to all / segment | ✅ | `backend/app/admin/notifications.py` — compose form + 3-way target dropdown; `notifications/segments.py` resolves each; `sender.send(...)` writes deliveries + bumps `delivered_count` |
| **US8.2** | Customer receives push while app is closed; opens app on tap | ⚠️ **Partial** — see below | Inbox + bell + foreground local-notifications ship; truly-out-of-process push requires FCM/APNs, stubbed via the `FcmSender` seam |

**About US8.2's partial verdict.** The doc says the notification arrives
"حتى لو التطبيق مقفول" — genuinely out-of-process push. Delivering that
requires Firebase Cloud Messaging (Android) or APNs (iOS) with real
service credentials. What ships in E8:

- All the infrastructure the FCM integration needs: `DeviceToken` table,
  `POST /api/v1/devices/register`, `FcmSender` stub, `SENDER=fcm` env
  switch.
- A close approximation for demo & testing: while the app is foregrounded,
  a 20-second inbox poller picks up new deliveries and fires an
  OS-level toast via `flutter_local_notifications`. Users see the
  notification and can tap through to `/notifications`.
- An in-app inbox with unread badge that survives app restarts (baseline
  tracked in SharedPreferences so old messages don't re-fire).

When Firebase is provisioned, the drop-in change is:
1. `pip install firebase-admin`, add credentials
2. Flip `SENDER=fcm` in `.env` and fill out `FcmSender.send(...)`
3. On mobile, add `firebase_messaging`, obtain the FCM token, POST it
   to `/api/v1/devices/register`

Nothing else in E1–E8 moves. Documented in the scope-boundary paragraph
of the plan file.

---

## In-session verification

Backend, live at `127.0.0.1:5000`:

- **Migration** `486a0a541b1d_e8_notifications` applied cleanly.
- **`/customers/lookup?phone=0555555555`** → `unread_notifications: 1` ✓
- **`/customers/9/notifications`** → returns the welcome delivery
  (unread) ✓
- **`/customers/9/notifications/1/read`** → flips `read_at` ✓
- **`/customers/lookup`** after read → `unread_notifications: 0` ✓
- **Segment resolver** — smoke tested by admin compose:
  - `all` → all seeded customers (2)
  - `has_ordered` → customers with linked orders (from seed: 2)
  - `inactive_30d` → 0 on a fresh seed (everyone ordered today)
- **5 new routes** registered (3 admin + 3 public + 1 device register).

Mobile: `flutter analyze` — no issues.

---

## Findings caught during the audit

### 1. Bell + inbox live outside auth — E9 lock-down pending

Same posture as loyalty lookup. Anyone who knows a phone can read that
customer's inbox and mark items read. E9 will layer session auth on the
lookup + inbox endpoints; nothing structurally has to move.

### 2. Inbox poller is 20s, not truly realtime

Deliberate — a 20s poll is negligible overhead per foreground app and
keeps the code simple. Post-MVP could bump this down to 5s via SSE or
skip polling entirely once FCM handles the wake-up.

### 3. `flutter_local_notifications` isn't available on all platforms

The `LocalPusher.show(...)` call wraps the plugin in a try/catch —
web/desktop simply skip firing. The inbox (in-app) still updates
correctly, so the customer never misses a message; only the OS toast
is platform-limited.

### 4. Baseline is per-customer

`InboxPoller` stores `last_seen_delivery_id.<customerId>` so switching
phones on the same install doesn't cross-fire notifications. A restart
picks up where it left off.

### 5. `notification_deliveries` scale

The seeder writes one row per (notification, customer). A 10k-customer
broadcast means 10k rows per broadcast. Fine for MVP; when volume grows,
partition by `notification_id` or archive read+old rows nightly.

### 6. Segment "inactive_30d" includes zero-order customers

Chosen for simplicity — a customer who signed up but never ordered is
the highest-value re-engagement target. If the shop wants a strict "was
active then went silent" segment, add a second resolver
`inactive_after_active()`.

### 7. `notifications.target_snapshot` is JSONB of ids

Chosen over a separate `notification_targets` table so the audit trail
is inline. For 10k+ recipients the JSONB column starts to feel bulky
(~40kb of ids); if that hits, switch to a proper join table.

None of these are gaps against the Word doc.

---

## Not verified in-session (needs a running Flutter session)

- Bell → inbox navigation.
- Local toast firing when admin sends while app is foregrounded.
- Baseline persistence across app restart.
- Empty state when the customer's phone has no records yet.

## Follow-ups (small, out of the E8 critical path)

- Firebase / FCM wire-up: replace `FcmSender.send`, add `firebase_messaging`,
  register token on the mobile side after asking permission.
- Mark-all-read button in the inbox.
- Delete-notification (admin).
- Per-order-status push (E4 admin transitions could enqueue "طلبك في
  الطريق").
- Move `notifications/lookup` behind session auth once E9 lands.
