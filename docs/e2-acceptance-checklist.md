# E2 — Acceptance Checklist

Every acceptance criterion in the Word doc's E2 section, restated as a manual
test step for the audit pass. Source: `853_..._Product_Backlog.docx` — Epic
E2 "السلة وإتمام الطلب" — US2.1 through US2.6.

## Setup

1. Backend up, DB migrated to `724553f6ce4f` (E2), `flask seed --wipe` fresh.
2. Flutter app running against that backend.
3. `/admin` login works.

---

## US2.1 — Add to cart (gated on required groups)

- [ ] Open the pizza (has required variant + size). Both must be picked before
      the CTA becomes enabled — hint text lists what's missing.
- [ ] After adding, a snackbar confirms and the cart badge in the AppBar
      increments.

## US2.2 — Edit qty / delete, live total

- [ ] Open the cart. Tap `+` on a line — quantity, line price, subtotal, and
      total all update immediately.
- [ ] Tap `-` down to 1, then again — the line is removed (going below 1
      deletes).
- [ ] Tap the trash icon — the line is removed.

## US2.3 — Fulfillment picker mandatory, address only when delivery

- [ ] Segmented control shows both options unselected initially.
- [ ] "مراجعة الطلب" is disabled with a red hint until a fulfillment is
      chosen.
- [ ] Choose pickup — no address field appears; CTA becomes enabled.
- [ ] Choose delivery — address field appears. CTA stays disabled with a
      "أدخل عنوان التوصيل" hint until an address is typed.

## US2.4 — Cross-sell horizontal list with quick-add

- [ ] After adding a pizza to the cart, a bottom sheet slides up with a
      horizontal list of recommended items (pasta + coke from seed).
- [ ] Each card shows image + name + price + a "+ إضافة" button.
- [ ] Tapping the coke's quick-add adds it in one tap (no required groups).
- [ ] Tapping the pasta's quick-add closes the sheet and opens the pasta
      details screen (because pasta has a required size group).

## US2.5 — Full order review before payment

- [ ] Cart CTA "مراجعة الطلب" navigates to the review screen.
- [ ] Each line shows: name, quantity × unit price, per-kind option
      breakdown (variant / size / add / remove — anything selected),
      per-line subtotal.
- [ ] Fulfillment recap card shows delivery + address, or pickup.
- [ ] Totals block shows subtotal + delivery fee (15.00 when delivery, hidden
      when pickup) + total, and totals sum correctly.
- [ ] "متابعة للدفع" fires the E3 stub snackbar.

## US2.6 — Admin links cross-sell items

- [ ] In `/admin`, open the pizza edit page. The "Cross-sell" section lists
      the two seeded links (pasta + coke).
- [ ] Add another cross-sell from the picker (pick any remaining item);
      it appears at the bottom.
- [ ] The picker never shows the current item itself, and never shows an
      item that's already linked.
- [ ] Change a link's `sort_order` and hit save — order updates.
- [ ] Delete a link with the trash button.
- [ ] Backend rejects a self-link and a duplicate (visible with an Arabic
      flash message; test by tweaking a form's hidden value or with
      `curl` if needed).

## Persistence

- [ ] Add lines + choose fulfillment. Kill the app, relaunch — cart lines
      and fulfillment survive.

## Cross-cutting

- [ ] Cart icon (with count badge) is visible in the AppBars on the
      categories, category-items and item-details screens.
- [ ] All strings render RTL Arabic.

---

## Audit pass

For every unchecked box: reproduce, capture the actual behaviour, fix, re-run.
Append findings to `docs/e2-audit-report.md`.
