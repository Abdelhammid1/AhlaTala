# E7 — Acceptance Checklist

Source: `853_..._Product_Backlog.docx` — Epic E7 "العروض والأكثر طلبًا" — US7.1..US7.3.

## Setup

1. Backend migrated to `12787600e1f0` (E7).
2. `flask seed --wipe` inserts one current offer (linked to the pizza)
   and one expired offer; also leaves 2 delivered orders (pizza × 2,
   coke × 3) so most-ordered has data.
3. Log in to `/admin`; app running.

---

## US7.1 — Admin creates offer with window, auto-hides after end

- [ ] `/admin/offers` shows both seeded offers with a "نشط الآن" badge
      on the live one and a "منتهي" badge on the expired one.
- [ ] Create a new offer with `starts_at = tomorrow` — status shows
      "لم يبدأ بعد" and `/api/v1/offers` does NOT include it.
- [ ] Edit an offer's `ends_at` to yesterday — status flips to "منتهي"
      and `/api/v1/offers` excludes it immediately.
- [ ] Toggle "إيقاف" — status becomes "موقوف" and `/api/v1/offers`
      excludes it, even if inside its window.
- [ ] Image upload works and shows the thumbnail on the list page.
- [ ] `linked_item_id` dropdown lists active items; picking one and
      saving means the mobile carousel's tap opens that item's details.

## US7.2 — Customer sees current offers on home

- [ ] Home screen shows an "العروض الحالية" section above الفئات.
- [ ] The section carousel shows only the live seeded offer, not the
      expired one.
- [ ] Tap the offer with `linked_item_id` set → item details opens.
- [ ] Deactivate the only live offer via admin → after pull-to-refresh
      the whole section disappears (no empty placeholder).

## US7.3 — Most-ordered auto-updates from order data

- [ ] "الأكثر طلبًا" section appears above الفئات (below offers).
- [ ] Order: coke (3 delivered) first, pizza (2 delivered) second.
- [ ] Place a new order for pasta and transition it to `delivered` via
      admin. After pull-to-refresh, pasta appears in the strip.
- [ ] Cancelled or preparing orders do NOT influence the ranking.
- [ ] Deactivating an item removes it from the strip (join filters
      out `is_active=false`).

## Cross-cutting

- [ ] Sections gracefully hide themselves when the API returns empty.
- [ ] Pull-to-refresh on home invalidates all three providers.
- [ ] `GET /api/v1/most-ordered?limit=3` caps at 3 rows.
- [ ] `GET /api/v1/most-ordered?limit=999` caps at the hard limit of 20.

---

## Audit pass

For every unchecked box: reproduce, capture actual behaviour, fix,
re-run. Append findings to `docs/e7-audit-report.md`.
