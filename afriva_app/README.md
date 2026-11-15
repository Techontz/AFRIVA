# Afriva mobile app (Flutter)

Short-drama streaming for African audiences. Dark, cinematic UI with a home
feed, a For You vertical feed, a full-screen vertical episode player,
My List, Profile, and a VIP / coins store with Mobile Money, card and bank checkout.

The app talks to the Afriva Laravel API (`/api/v1`). See `../SPEC.md` (§1 design, §2 mobile, §6 API).

## Requirements

- Flutter 3.47+ / Dart 3.13+
- The backend running locally (`php artisan serve` → http://localhost:8000)

## Run

```bash
flutter pub get

# Android emulator (default API URL: http://10.0.2.2:8000/api/v1)
flutter run

# iOS simulator / web / desktop (default API URL: http://localhost:8000/api/v1)
flutter run -d ios
flutter run -d chrome

# Physical device or remote server: set the URL explicitly
flutter run --dart-define=API_URL=http://192.168.1.20:8000/api/v1
```

Dev networking is pre-configured: Android has the `INTERNET` permission, and
`usesCleartextTraffic="true"` only in the debug/profile manifests (release builds
require HTTPS); iOS has `NSAllowsLocalNetworking` (and arbitrary loads for media).

## Release builds (production and staging)

The API is chosen at build time with `--dart-define=API_URL=...` (see
`lib/core/config.dart`). A release build without `API_URL` uses production,
`https://api.afriva.co.tz/api/v1`. Always pass the staging URL explicitly for
staging builds, otherwise they talk to production:

| Target | API_URL |
|---|---|
| Production | `https://api.afriva.co.tz/api/v1` (the release default) |
| Staging | your staging API, e.g. `https://staging-api.afriva.co.tz/api/v1` |

Bump `version:` in `pubspec.yaml` (`1.0.0+1` = name + build number) before each
store upload; the build number must increase every time.

### Android (Play Store app bundle)

One-time signing setup (the keystore and its passwords never go to GitHub):

```bash
keytool -genkey -v -keystore ~/afriva-upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties
# edit android/key.properties: passwords, alias, absolute storeFile path
```

`android/key.properties` and `*.jks` are git-ignored. Without `key.properties`
release builds are signed with the debug key (local testing only, the Play
Console rejects them).

```bash
# Production
flutter build appbundle --release \
  --dart-define=API_URL=https://api.afriva.co.tz/api/v1
# -> build/app/outputs/bundle/release/app-release.aab

# Staging (install directly on test phones)
flutter build apk --release \
  --dart-define=API_URL=https://staging-api.afriva.co.tz/api/v1
```

### iOS (App Store / TestFlight)

Needs a Mac with Xcode and an Apple Developer account. Open
`ios/Runner.xcworkspace` once, select the Runner target > Signing & Capabilities,
choose your team (bundle id `com.afriva.afrivaApp`) and keep automatic signing.

```bash
# Production
flutter build ipa --release \
  --dart-define=API_URL=https://api.afriva.co.tz/api/v1
# -> build/ios/ipa/*.ipa, upload with Transporter or:
#    xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>

# Staging
flutter build ipa --release \
  --dart-define=API_URL=https://staging-api.afriva.co.tz/api/v1
```

## Demo accounts (seeded by the backend)

| Account | Password | Notes |
|---|---|---|
| `viewer@afriva.com` | `password` | Regular viewer with coins |
| `vip@afriva.com` | `password` | Active monthly VIP |

Debug builds show these as quick-fill chips on the login screen.

## Project layout

```
lib/
  core/        config, theme (design tokens), API client (Dio + bearer token + error mapping), router, formatting, haptics
  models/      Drama, Episode, User/Subscription, Plan/PaymentMethod/Payment, Home/Feed/History
  services/    auth, catalog, player (play/unlock/progress), commerce (plans/checkout/polling), me
  state/       AuthState, FavoritesState, SettingsState (provider ChangeNotifiers)
  features/    splash, shell, home, foryou, drama, player, mylist, profile, vip, auth, search
  widgets/     logo, posters, ranking tiles, episode grid, skeletons, empty/error states, sheets
```

## Tests

```bash
flutter analyze
flutter test        # offline widget smoke tests (no network needed)
```
