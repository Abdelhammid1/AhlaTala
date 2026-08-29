# أحلى طلة — Mobile (Flutter)

Customer app. E1 scope: browse categories → items → item details with option groups
(variant / size / remove / add) and a running total price.

## Run

```powershell
cd mobile
flutter pub get

# Point at your Flask backend. Defaults to Android emulator's host loopback (10.0.2.2:5000).
# iOS simulator / web / desktop should use 127.0.0.1:
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

## Structure

- `core/` — theme, Dio client, env config
- `data/` — models (Category, Item, OptionGroup, Option) + `MenuRepository`
- `features/menu/` — categories grid, items list
- `features/item_details/` — details screen, `item_configuration_controller` (the
  price/selection engine), option-group widget, nutrition sheet

## What's stubbed (E2 will fill in)

The "Add to cart" button is fully wired to the configuration controller
(enable/disable rules are real), but tapping it only shows a snackbar. E2 replaces
`_stubAdd` in `item_details_screen.dart` with the real cart-add call — nothing else
on this screen needs to change.
