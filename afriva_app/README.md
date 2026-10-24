# Afriva — mobile app (Flutter)

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

`API_URL` also works for builds:

```bash
flutter build apk --release --dart-define=API_URL=https://api.afriva.com/api/v1
```

Dev networking is pre-configured: Android has the `INTERNET` permission and
`usesCleartextTraffic="true"`; iOS has `NSAllowsLocalNetworking` (and
arbitrary loads for media). Use HTTPS in production and remove the cleartext flag.

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
