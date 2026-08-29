# E4 — Audit Report

Phase 3 pass over every AC in the Word doc's E4 section against the code as
it stands. Source: `853_..._Product_Backlog.docx` — Epic E4 "إدارة الطلبات
(Admin)" — US4.1 through US4.3.

---

## Per-story verdicts

| Story | AC | Verdict | Where |
|---|---|---|---|
| **US4.1** | New orders appear immediately with clear indicator | ✅ (~15s max) | `admin/orders.py` `_unseen_new_count` + context processor + nav badge in `templates/admin/base.html`; `templates/admin/orders/list.html` row highlight, "جديد" badge, `<meta http-equiv="refresh" content="15">` |
| **US4.2** | Manual status updates, logical order only, reflected in mobile | ✅ | `Order.next_valid_statuses()` (single source of truth); admin UI renders only valid buttons; `orders_transition` route re-validates; mobile confirmation screen polls every 15s + `RefreshIndicator` for pull-to-refresh; terminal statuses stop the timer |
| **US4.3** | Full order details for admin | ✅ | `templates/admin/orders/detail.html` — customer / fulfillment / payment cards + lines with per-kind selections + totals + status transitions |

Doc note honoured: **no driver app, no live tracking, status is always
manual from admin.**

---

## In-session verification

Backend, live at `127.0.0.1:5000`:

- **Migration**: `beb9a36d3739_e4_order_workflow_statuses_admin_seen_at` applied.
  Enum extension done via `ALTER TYPE ... ADD VALUE IF NOT EXISTS` for each
  of `preparing`, `on_the_way`, `ready_for_pickup`, `delivered`. Idempotent.
- **Seeder** creates 3 orders on `--wipe`:
  - `#3 AT-2026-000003` — status **confirmed**, delivery — has "جديد" badge (unseen)
  - `#4 AT-2026-000004` — status **preparing**, delivery
  - `#5 AT-2026-000005` — status **delivered**, pickup
- **Transitions** validated by helper:
  - confirmed → `[preparing, cancelled]` ✓
  - preparing (delivery) → `[on_the_way, cancelled]` ✓
  - delivered → `[]` (terminal) ✓
- **4 admin routes** registered under `/admin/orders/*`.

Mobile: `flutter analyze` — no issues.

---

## Findings caught during the audit

### 1. Status label "مؤكد — جديد" was misleading for seen-but-still-confirmed orders

**File:** `backend/app/admin/orders.py`

Original label appended "— جديد" to the `confirmed` badge, which stayed
after the admin opened the order (badge only cleared elsewhere). Fixed to
plain "مؤكد"; the "new" signal now comes only from the row-level "جديد"
badge and the yellow row highlight, both driven by `admin_seen_at IS NULL`.

### 2. "Immediate" reflection is ~15s worst-case

Meta-refresh interval on the admin list and `Timer.periodic` on the mobile
confirmation screen both use 15 seconds. Doc says "فور" ("immediately");
15s is a pragmatic MVP interpretation without wiring realtime plumbing.
E8 will add push for the mobile side; a JS `EventSource` / SSE could tighten
the admin side later.

### 3. `admin_seen_at` is single-flag, not per-admin

Once ANY admin opens the order the badge clears for everyone. Correct for
the current one-admin setup; multi-admin roles are out of scope. When
multi-admin lands, replace `admin_seen_at` with a `seen_by` join table.

### 4. Mobile polling continues in the background

The `Timer.periodic` keeps firing when the app is backgrounded. Trivial
network churn — one GET per 15s — but on a paused app it's still waste.
Recording as a follow-up: wire `WidgetsBindingObserver.didChangeAppLifecycleState`
to pause/resume the timer.

### 5. `_seed_sample_orders` runs only on `--wipe`

Intentional: without the guard, every `flask seed` would spam three more
sample orders. `--wipe` is the "fresh dev DB" gesture.

### 6. Transition endpoint responds via **redirect + flash**, not JSON

Admin routes are session-authed Jinja pages, so an invalid transition
flashes an Arabic message and redirects back to the detail page. That's
consistent with the rest of the admin UI (categories/items/options). API-
style transitions (for a future mobile-admin app) would go via
`/api/v1/orders/<id>/transition` and return JSON; not needed for E4.

---

## Not verified in-session (needs a running Flutter session + a live browser)

- Full end-to-end: place order in Flutter → row appears with "جديد" badge
  in admin within 15s.
- Admin transitions reflected on the mobile timeline.
- Terminal state stops the mobile poll timer.

## Follow-ups (small, out of the E4 critical path)

- Pause the mobile poll timer while the app is in the background.
- SSE / long-poll on the admin list to tighten "immediate" from ~15s to
  ~1s. Optional — meta-refresh is sufficient for a small kitchen.
- Add an audit log (`order_status_history`) so we can see who moved a
  status when — natural once multi-admin arrives.
- A hidden `/admin/orders?played=1` audio-ping mode would be helpful for
  the kitchen: unseen count > 0 → chime. Zero deps needed; ~10 lines of
  JS.
