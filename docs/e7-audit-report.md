# E7 — Audit Report

Phase 3 pass over every AC in the Word doc's E7 section against the code as
it stands. Source: `853_..._Product_Backlog.docx` — Epic E7 "العروض
والأكثر طلبًا" — US7.1..US7.3.

---

## Per-story verdicts

| Story | AC | Verdict | Where |
|---|---|---|---|
| **US7.1** | Admin creates offer with window; auto-hidden after end | ✅ | `backend/app/admin/offers.py` full CRUD + toggle; `templates/admin/offers/*` render "نشط الآن / منتهي / موقوف / لم يبدأ بعد" badges; `/api/v1/offers` filters `is_active AND starts_at <= now <= ends_at` |
| **US7.2** | Home shows a section for current offers | ✅ | `offersProvider` → `_OffersSection` carousel on `CategoriesScreen`; hidden when empty; tap deep-links to `linked_item_id` when set |
| **US7.3** | Most-ordered auto-derives from real order data | ✅ | `/api/v1/most-ordered` — `SUM(order_lines.quantity)` grouped by item, filtered to `orders.status = 'delivered'` and `items.is_active`, ordered desc — no admin toggle involved |

---

## In-session verification

Backend, live at `127.0.0.1:5000`:

- **Migration** `12787600e1f0_e7_offers` applied cleanly.
- **`/api/v1/offers`** returns exactly the 1 currently-active seeded offer
  ("عرض الأسبوع — خصم على البيتزا"), linked to the pizza; the expired
  "عرض رمضان (منتهي)" is auto-filtered ✓
- **`/api/v1/most-ordered?limit=5`** returns:
  1. `كوكاكولا` (3 delivered)
  2. `بيتزا مارجريتا` (2 delivered)
  ✓ correctly ordered
- **7 new routes** registered: 5 under `/admin/offers/*`, 2 public
  (`/api/v1/offers`, `/api/v1/most-ordered`).

Mobile: `flutter analyze` — no issues.

---

## Findings caught during the audit

### 1. Home is a plain `ListView`, not slivers

Chose `ListView` + a nested `GridView(shrinkWrap: true, physics: NeverScrollable)`
over a `CustomScrollView + SliverGrid` because the sections are small (≤ 3
categories today) and the code stays flatter. If the categories grid grows
to dozens of tiles, revisit — SliverGrid handles that more efficiently.

### 2. Most-ordered is all-time, no window

Deliberate scope choice (documented in the plan). If the shop wants a
"trending this week" feel, add `AND orders.confirmed_at >= now - 7 days`
to the aggregation and expose a `?window=` param. Fallback logic (fall
back to all-time when the window is empty) is easy to layer in.

### 3. No cache on `/most-ordered`

The query is `O(order_lines_delivered)`. At MVP volumes (dozens of orders/
day) this is fine; the whole endpoint runs in a single millisecond. When
volume grows, a Redis 5-minute cache OR a nightly materialised view
solves it without any client-side change.

### 4. Sections hide when empty rather than showing a placeholder

Cleaner UX than "no offers right now" boilerplate. The section title is
inside the same `Column` that renders the carousel, so both vanish
together on empty data. Recorded so the "why does my new offer not show
a section title" question doesn't come up during audit.

### 5. Offer image is optional; falls back to a gradient

A gradient banner is nicer than an empty box when an admin creates an
offer without uploading art. The title/description text sits on a bottom
darken overlay so it stays legible on either.

### 6. `orders.confirmed_at` on delivered orders is not the same as
`delivered_at`

We don't track a separate `delivered_at` timestamp — the status flip
happens via the E4 admin action, and only `updated_at` records when. If
the shop wants "delivered in the last N days" for most-ordered, add a
`delivered_at` column + set it in the `orders_transition` route.

None of these are gaps against the Word doc.

---

## Not verified in-session (needs a running Flutter session)

- Offers carousel horizontal swipe + tap → item deep-link.
- Most-ordered horizontal scroll + tap → item deep-link.
- Pull-to-refresh invalidating all three providers.
- Empty-section hiding behaviour.

## Follow-ups (small, out of the E7 critical path)

- Add a "last N days" window param to `/most-ordered`.
- Redis or materialised-view cache for `/most-ordered` when order volume
  grows.
- Drag-sort UI for offers in admin (backend already respects `sort_order`).
- Push notifications on newly-published offers (E8).
- Analytics: count taps per offer id so the shop knows which cards worked.
