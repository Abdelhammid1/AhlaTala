# أحلى طلة — Mobile App

Flutter customer app for the أحلى طلة restaurant. Ships to both **Google
Play** (Android) and **App Store** (iOS) from the same codebase.

- **Package / Bundle ID:** `ai.manasety.ahlatala`
- **Version:** `1.1.0+3`
- **Backend:** `https://ahlatala.manasety.ai` (Flask API)
- **Live-updates repo (this one):** `github.com/ibrahimfakhrey/ahla-tala-mobile-`
- **Monorepo (backend + landing + admin templates):** `github.com/Abdelhammid1/AhlaTala`

## Build cheatsheet

### Android — signed `.aab` for Play Console

```bash
flutter build appbundle --release
```

- Signs with `android/app/upload-keystore.jks` (**not** committed — see
  Signing below).
- Output: `build/app/outputs/bundle/release/app-release.aab` (~47 MB).
- Bump `pubspec.yaml` `version:` before every Play upload; Play requires
  `versionCode` strictly increasing.

### iOS — App Store via Xcode Cloud

Xcode Cloud runs `flutter pub get` + `pod install` + `xcodebuild archive`
automatically on every push to `main`. No CI config lives in this repo —
it's all in App Store Connect → your app → Xcode Cloud → Workflows.

Recommended workflow (set once in App Store Connect):

- **Start condition:** Branch changes → `main`
- **Environment:** macOS latest, Xcode 15+
- **Action:** Archive → iOS → any device
- **Post-action:** TestFlight → Internal Testing group

To build locally on a Mac:

```bash
flutter build ipa --release
open build/ios/archive/Runner.xcarchive
# → Distribute App → App Store Connect → Upload
```

## Signing

### Android upload keystore

The upload key is **not committed**. To recreate the release build
locally you need `android/key.properties` + `android/app/upload-keystore.jks`
with the ownership set by whoever holds the Play Console account.

Contents of `key.properties` (values shared out-of-band):

```properties
storeFile=upload-keystore.jks
storePassword=•••
keyPassword=•••
keyAlias=upload
```

### iOS signing

Xcode Cloud handles code signing automatically via App Store Connect
API keys. For local Mac builds, use "Automatically manage signing" in
Xcode → Signing & Capabilities with an Apple Developer Program account
that owns the `ai.manasety.ahlatala` bundle identifier.

## Environment overrides

The API base URL defaults to production. Override for local dev:

```bash
# Android emulator hitting your Mac/PC's local Flask
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000

# iOS simulator hitting your Mac's local Flask
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000

# Real device on wifi hitting your Mac/PC on LAN
flutter run --dart-define=API_BASE_URL=http://192.168.x.y:5000
```

## Architecture (whistle-stop tour)

- **State:** Riverpod 2 (`flutter_riverpod`). Every screen is a
  `ConsumerWidget` / `ConsumerStatefulWidget`; providers live under
  `lib/features/*/providers/`.
- **HTTP:** Dio with a JWT-attaching interceptor + retry-on-transient
  (2s → 5s, network + 502/503/504). See `lib/core/network/dio_client.dart`.
- **Routing:** go_router. Route table in `lib/main.dart`.
- **Theme:** `lib/core/theme/app_theme.dart` — full Stitch token set,
  Space Grotesk (headlines) + Plus Jakarta Sans (body) via `google_fonts`.
- **Icons:** Bootstrap Icons in admin panels, Material Icons here.

## Screens

```
Home (categories + most-ordered + offers)
├── Menu (search-first flat browse)
├── Item details (options, calories, add-to-cart)
├── Cart / Review (fulfillment, discount, points, payment)
├── Order tracking (live status polling every 15s)
├── Order rating (delivered orders → 1-5 stars + tags + comment)
├── Login (phone entry → OTP)
├── Verify OTP (6-digit tiles → session)
├── Profile (identity, loyalty balance card, quick actions)
├── Saved addresses (CRUD, set default)
├── Order history (filter chips, reorder, rate)
└── Notifications inbox (unread / read grouping, promo detection)
```

## Deploy checklist

Before each `.aab` / `.ipa` upload:

1. Bump `pubspec.yaml` `version:` (both name and `+N` build number).
2. Backend at `ahlatala.manasety.ai` matches this build's API contract
   (currently: `POST /api/v1/me/orders/:id/rating` requires the
   `orders.rating*` columns from the `7be0571769cd` migration).
3. `flutter analyze` clean.
4. `flutter test` clean (once test suite is fleshed out).
5. Test the full sign-in → order → track → rate flow on a real device.
6. For Play: build .aab → Play Console → Internal testing → Rollout.
7. For App Store: push to `main` → Xcode Cloud builds + uploads to
   TestFlight automatically. Promote via App Store Connect UI.
