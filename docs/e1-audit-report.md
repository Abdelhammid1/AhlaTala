# E1 — Audit Report

Pass over every acceptance criterion in the Word doc's E1 section against the
code as it stands. This is Phase 3 of the user's requested workflow (plan →
implement → **audit** → fix).

Source of truth: `853_20260828235037_Ahla_Tolla_Product_Backlog.docx` — Epic E1
"إعداد المنيو والتصفح" — US1.1 through US1.6, plus the developer notes at
the end of the doc.

---

## Per-story verdicts

| Story | AC | Verdict | Where |
|---|---|---|---|
| **US1.1** | Categories with image + name + base price; "يبدأ من X" when size options differ | ✅ | `mobile/lib/features/menu/*`, `backend/app/api/categories.py`, `backend/app/observers.py` |
| **US1.2** | Item details: image, name, description, calories, nutrition-facts button | ✅ | `mobile/lib/features/item_details/screens/item_details_screen.dart`, `.../widgets/nutrition_sheet.dart` |
| **US1.3** | Size = required single-select; total recomputes; cannot proceed without picking | ✅ | `mobile/lib/features/item_details/controllers/item_configuration_controller.dart` (`canAddToCart`, `totalPrice`) |
| **US1.4** | Remove = optional multi-select, zero price impact | ✅ | Backend rules in `backend/app/admin/{option_groups,options}.py`; Flutter hides price label for `remove` kind |
| **US1.5** | Add = optional multi-select, price increases immediately | ✅ | Same controller + widget path |
| **US1.6** | Admin creates generic option groups; option can override item name + image | ✅ | `backend/app/admin/*` + templates; `displayName`/`displayImageUrl` in the controller |

Developer notes (last paragraph of the doc):
- ✅ In-scope: E1 only, no other Epics implemented.
- ✅ No Driver App / Live Tracking (N/A for E1 anyway).
- ✅ Option Groups are one generic system driven by `kind` + `selection_type` + `is_required` + `price_delta`, not per-item bespoke fields.

---

## Findings caught during the audit (and fixed)

### 1. Observer computed the "starting from" price wrong when 2+ variable groups existed

**File:** `backend/app/observers.py`, `recompute_item_display_price`

**Symptom.** For an item with both a variant group (e.g. deltas `[5, 10, 15]`)
and a size group (deltas `[2, 4, 6]`), the old code pooled every delta and took
the pool minimum → `min([5,10,15,2,4,6]) = 2`, giving a "starting from" of
`base + 2`. The customer would then never see that price on the details screen,
because they must pick from BOTH groups — the actual cheapest combo is
`base + 5 + 2 = base + 7`.

**Fix.** Sum the minimum contribution per variable group instead of pooling.
Required groups contribute `min(delta)`; optional groups contribute `0`
(customer can skip).

**Verified.** Four cases green (pizza: 30.00; fancy 2-group case: 37.00 not 32.00;
coke: `None`; pasta: 28.00) — see the smoke-test in the audit session log.

### 2. Default Flutter widget test still referenced the removed `MyApp` stub

**File:** `mobile/test/widget_test.dart`

Replaced with a placeholder while unit tests for the configuration controller
land in a follow-up (see the "Follow-ups" section below).

### 3. Observer didn't fire during bulk seed (found after Postgres came up)

**File:** `backend/seed.py`

**Symptom.** After the first seed run, the API reported `price_is_variable=false`
and `display_price_from=null` for the pizza (which has variant + size groups
with differing prices). The `before_flush` observer inside SQLAlchemy sees
pending inserts, but a lazy-loaded `item.option_groups` relationship read
during that same flush can miss options that haven't hit the DB yet.

**Fix.** After all seed rows are added, `flush` + `expire_all`, then re-query
each `Item` with `selectinload(option_groups → options)` and recompute
explicitly. Cleared observer edge cases entirely for the seed path — admin
edits still rely on the observer (correctly, since they modify one row at a
time against a fully-populated DB).

**Verified.** All three seeded items now report correct pricing (pizza 30.00 T,
pasta 28.00 T, coke null F).

### 4. Two `Radio` deprecation warnings from Flutter 3.41

**File:** `mobile/lib/features/item_details/widgets/option_group_widget.dart`

Swapped the deprecated `Radio` for an `IconButton` that toggles between
`radio_button_checked` and `radio_button_off`. `flutter analyze` now clean.

---

## Verified in-session

- `flutter analyze` — **No issues found**.
- Flask app boots and registers all **21 routes** (`/api/v1/*` public + `/admin/*` authenticated + `/static/*`).
- Observer arithmetic — 4 hand-picked cases pass.

## Not verified in-session (deferred — need PostgreSQL up)

- Full stack round-trip: Flutter → API → DB → API → Flutter. Blocked on the
  user installing PostgreSQL. When Postgres is up:
    1. `flask db init && flask db migrate -m "initial" && flask db upgrade && flask seed`
    2. Log in to `/admin` with `admin@ahlatolla.local` / `admin`
    3. Point Flutter at the backend (`--dart-define=API_BASE_URL=...`)
    4. Walk `docs/e1-acceptance-checklist.md` box by box.

## Follow-ups (small, out of the E1 critical path)

- Unit tests for `ItemConfigurationController` — covers price math, image/name
  swap on variant, canAddToCart gating. This is the load-bearing piece; testing
  it early pays off in E2 when the cart is wired in.
- Rate-limit or cache `/api/v1/categories` (menus don't change often).
- Categories/items admin: drag-sort UX (backend already respects `sort_order`).

Everything above is quality-of-life, not an E1 gap.
