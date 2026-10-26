# Afriva: mobile app (Flutter)

Short-drama streaming for African audiences. The whole interface is in
**Kiswahili** (English is only an optional fallback in Settings).

- Bottom navigation: **Nyumbani · Tafuta · Vipendwa · Profile**.
- Home: greeting, *Endelea kutazama* (continue watching), *Zinazovuma*, *Mpya*, category rows; the For You vertical feed opens from Home.
- Series page: poster, trailer, synopsis, episode count, runtime, age rating, and a free / locked label with price on every episode (episodes 1-8 free by default).
- Player: play/pause/seek/retry, resume where you stopped, auto-next, quality picker (Auto/480p/720p/1080p), progress saving and playback analytics (`POST /events`, `X-Device-Id`).
- VIP & coins store: Tanzania mobile money and international cards; methods that are not yet connected show *Inakuja hivi karibuni*; receipts and coin history in Profile.
- **Wasilisha Kazi Yako** (Creator Studio): apply as a creator, accept the revenue agreement, create series, upload episodes, send for review with a rights declaration, and follow the review status and reviewer notes. Uploading never publishes: AFRIVA reviews and publishes.

The app talks to the Afriva Laravel API (`/api/v1`). See `../SPEC.md` (§1 design, §2 mobile, §6 API, §8 project scope).

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
  models/      Drama, Episode, User/Subscription, Plan/PaymentMethod/Payment/Receipt/CoinTransaction, Home/Feed/History, Studio (creator)
  services/    auth, catalog, player (play/unlock/progress/events), commerce (plans/checkout/polling/receipts), me, creator, file picker
  state/       AuthState, FavoritesState, SettingsState (provider ChangeNotifiers)
  features/    splash, shell, home, foryou, drama, player, mylist, profile, vip, auth, search, creator
  l10n/        Kiswahili strings (sw_watch, sw_account, sw_creator)
  widgets/     logo, posters, ranking tiles, episode grid, skeletons, empty/error states, sheets
```

## Tests

```bash
flutter analyze
flutter test        # offline widget smoke tests (no network needed)
```
