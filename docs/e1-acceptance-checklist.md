# E1 — Acceptance Checklist

Restates every acceptance criterion (AC) from the Word doc's E1 section as a
manual test step. Used in Phase 3 audit.

Source of truth: `853_20260828235037_Ahla_Tolla_Product_Backlog.docx` — Epic E1
"إعداد المنيو والتصفح" — user stories US1.1 through US1.6.

## Setup

1. Backend up and seeded (`flask seed`, `flask run`). Confirm 3 categories + 3 items.
2. Flutter app running against that backend.
3. Log in to `/admin` — admin panel loads in Arabic RTL.

---

## US1.1 — Categories + starting-from price

- [ ] Categories screen shows the 3 seeded categories (بيتزا، باستا، مشروبات).
- [ ] Each tile shows: image (or placeholder), Arabic name, item count.
- [ ] Tap a category → items list appears.
- [ ] The pizza (`بيتزا مارجريتا`) shows **"يبدأ من X ريال"** (variant+size groups make its price variable).
- [ ] The pasta (`باستا أرابياتا`) shows **"يبدأ من X ريال"** (its size group has 2 different prices).
- [ ] The drink (`كوكاكولا`) shows a **flat base price** — no "يبدأ من" prefix (it has no variant/size group).

## US1.2 — Item details + nutrition

- [ ] Tap an item → details screen opens.
- [ ] Screen shows: large image, Arabic name, Arabic description, calories chip.
- [ ] "Nutrition Facts" action in the app bar opens a bottom sheet with calories.
- [ ] For the coca-cola (no option groups), only base info is visible — no groups render.

## US1.3 — Mandatory size, live total

- [ ] For the pizza, both **نوع البيتزا** and **الحجم** groups render as single-select radios and are marked **إجباري**.
- [ ] Add-to-cart is disabled while any required group is unmet (a hint lists which).
- [ ] Picking a size updates the total price immediately.
- [ ] Cannot deselect a required single-select group's only choice.

## US1.4 — Remove ingredients (no price change)

- [ ] Pizza's **حذف مكونات** group renders as multi-select checkboxes, marked **اختياري**.
- [ ] Options in this group show no price label.
- [ ] Toggling any of them does NOT change the total price.
- [ ] In `/admin`, an option in a `remove` group cannot be saved with a non-zero `price_delta` (server-side rejection with an Arabic message).

## US1.5 — Add ingredients with extra price

- [ ] Pizza's **إضافات** group renders as multi-select, **اختياري**, each option shows "+X ريال".
- [ ] Toggling an option updates the total price by exactly its `price_delta`.
- [ ] Toggling multiple additions accumulates.

## US1.6 — Admin defines groups generically

- [ ] In `/admin`, open the pizza item → the item form lists all 4 option groups inline.
- [ ] "New Option Group" form exposes every field: nameAr/nameEn, kind (variant/size/remove/add), selection_type (single/multi), is_required, sort_order.
- [ ] Creating a `remove` group with `is_required=true` is rejected (Arabic error).
- [ ] Creating a `remove` group with `selection_type=single` is rejected.
- [ ] Creating an Option under a `remove` group with `price_delta != 0` is rejected.
- [ ] An Option's image, when uploaded, overrides the item's image in the app when that option is selected (test with a variant option that has an image).
- [ ] Changing an option's `price_delta` in admin causes the item's `display_price_from` to be recomputed (visible on the items list column).

## Cross-cutting

- [ ] The whole app renders RTL.
- [ ] All user-facing strings are in Arabic.
- [ ] Images load over the network from the Flask backend (absolute URLs).

---

## Audit pass (Phase 3)

For every unchecked box: reproduce, capture what actually happened, fix the code,
re-run. When every box is ticked, E1 is done.
