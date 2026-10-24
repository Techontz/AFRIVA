# AFRIVA — Platform Spec (shared contract)

Afriva is a short-drama streaming platform (vertical, episodic mini-series) for African audiences.
Three apps share ONE API:

| Part | Path | Stack | Dev URL |
|---|---|---|---|
| Backend API | `backend/` | Laravel 11+, Sanctum, MySQL | http://localhost:8000 |
| Web (viewer site + Super Admin + Studio portal) | `afriva_web/` | Next.js (App Router, TypeScript, Tailwind) | http://localhost:3000 |
| Mobile app | `afriva_app/` | Flutter | — |

Currency default: **TZS**. All money stored as integer minor-less amounts (TZS has no decimals) in `amount` columns (BIGINT).

---

## 1. Brand & design system (use identically in web and app)

Original Afriva identity — do NOT copy any third-party logo, artwork or copy.

- Theme: dark, cinematic.
  - `bg` #0B0B0F, `surface` #15151C, `surface-2` #1E1E28, `border` #2A2A36
  - `text` #FFFFFF, `text-muted` #A1A1B5, `text-dim` #6B6B80
  - `primary` #FF4D2E (Afriva coral), `primary-2` #FF8A00 (amber) → brand gradient `linear-gradient(135deg,#FF4D2E,#FF8A00)`
  - `gold` #F5C044 (VIP / coins), `success` #22C55E, `danger` #EF4444
- Font: **Plus Jakarta Sans** (Google Fonts) — 400/500/600/700/800. Headings 700–800, tight letter-spacing.
- Logo: wordmark "AFRIVA" in 800 weight with the "A" glyph in the brand gradient + a small play-triangle mark. Build as SVG/text, no images.
- Posters: vertical **3:4**, radius 8px (web) / 10px (app), subtle bottom gradient, top-left badge ("Hot", "New", "VIP"), bottom-right "EP 60" style episode count.
- Cards show: poster, title (2 lines max), episode count, 1–2 genre tags as small muted chips.
- Ranking list: big outlined rank numerals 1–10 (top 3 in brand gradient), poster thumb, title, tags, view count.
- Buttons: pill (radius 999), primary = brand gradient; secondary = surface-2.
- Motion: 150–250ms ease transitions; hover scale 1.03 on posters (web).

## 2. Viewer experience

Web (`afriva_web`):
- Header (sticky, blurred dark): logo · Home · Browse · Rankings · VIP · App download · search field · language selector (English/Kiswahili label only) · Log in / avatar.
- Home: hero carousel (featured drama: wide backdrop, poster, title, episode count, synopsis, tags, "Watch Now" button, prev/next + page dots) → rows with heading + "More >": **Must-Watch**, **Trending Now** (ranked list), **New Releases**, **Hidden Gems**, **Romance**, **Revenge**, etc.
- Browse: category chips (All, Romance, Revenge, Billionaire, Family, Comedy, Thriller, Historical, Village Life, Campus…), sort (Popular/Newest), infinite/paged grid.
- Drama detail `/drama/[slug]`: backdrop, poster, title, tags, episode count, views, synopsis, "Play EP1", Add to My List, episode grid (1..N buttons; lock icon on locked eps; VIP crown), "You may also like".
- Watch `/drama/[slug]/ep/[n]`: vertical 9:16 player centered with dark side panels, episode selector panel on the right (ranges 1-30, 31-60), prev/next. Locked episode → paywall modal (subscribe or unlock with coins).
- VIP / Subscribe `/vip`: plan cards from `/plans` (weekly, monthly, yearly, episode packs e.g. "6 episodes – 10,000 TZS", coin packs), then payment-method picker grouped: **Mobile Money** (M-Pesa, Tigo Pesa / Mixx by Yas, Airtel Money, HaloPesa, T-Pesa), **Cards** (Visa, Mastercard), **Bank** (CRDB, NMB, NBC), showing phone input for mobile money / card form UI for cards. Submit calls checkout; shows "Pending — payment provider not yet connected" state.
- Account: login/register, My List, Watch History, Subscription status, coin balance, payment history.
- Footer: About (Terms, Privacy, Cookies), Contact (Business, Careers, Press), Community (Facebook, Instagram, TikTok, YouTube), email, © Afriva.

Mobile (`afriva_app`): bottom nav **Home · For You · My List · Profile**.
- Home: top tabs (Popular, New, Romance, Revenge, …), banner carousel, rows, ranking.
- For You: full-screen vertical PageView feed of episode 1 of dramas (TikTok-style), right-side actions (My List, Episodes, Share), bottom title + "Watch full series".
- Player: full-screen vertical video, swipe up/down between episodes, episodes bottom sheet with ranges, lock → paywall bottom sheet.
- VIP store screen identical in function to web /vip. Profile: coins, VIP status, history, settings, login.

## 3. Roles

`users.role` ∈ `viewer` | `company` | `super_admin`.
- **super_admin**: manages everything (companies, company logins, plans, categories, all dramas, payment methods, users, payments, revenue share, platform settings).
- **company** (a movie studio/production house; `users.company_id` set): manages own dramas & episodes, sees own stats (views, watchers, earnings, per-drama breakdown, daily chart), payout records.
- **viewer**: watches, subscribes.

## 4. Data model (MySQL)

- `users` id, name, email (unique, nullable), phone (unique, nullable), password, role, company_id nullable, coins INT default 0, avatar_url, status (active|suspended), timestamps
- `companies` id, name, slug, logo_url, email, phone, country, revenue_share_percent (DECIMAL 5,2 default 70.00 — company's share), status (active|suspended), description, timestamps
- `categories` id, name, slug, sort_order
- `dramas` id, company_id, title, slug, synopsis, poster_url, backdrop_url, total_episodes (cached), free_episodes INT default 5, coins_per_episode INT default 30, status (draft|published), is_featured, badge nullable (hot|new|vip), language, release_date, views BIGINT default 0, timestamps
- `category_drama` pivot
- `tags` / `drama_tag` (free-form tags like "Billionaire", "Secret Identity")
- `episodes` id, drama_id, number, title, video_url, thumbnail_url, duration_seconds, is_free (derived: number <= drama.free_episodes unless overridden), views, timestamps; unique(drama_id, number)
- `plans` id, name, type (weekly|monthly|yearly|episodes|coins), price (BIGINT), currency, duration_days nullable, episode_quota nullable, coins nullable, bonus_coins nullable, description, features JSON, is_popular, is_active, sort_order
- `payment_methods` id, code (mpesa, tigopesa, airtelmoney, halopesa, tpesa, visa, mastercard, crdb, nmb, nbc), name, type (mobile_money|card|bank), logo_url nullable, color, is_enabled, is_integrated (false by default), sort_order, config JSON (encrypted, nullable)
- `payments` id, user_id, plan_id, payment_method_code, reference (unique), amount, currency, phone nullable, status (pending|success|failed|cancelled), provider_reference nullable, meta JSON, paid_at, timestamps
- `subscriptions` id, user_id, plan_id, payment_id, type, starts_at, ends_at nullable, episodes_remaining nullable, status (active|expired|cancelled), timestamps
- `episode_unlocks` id, user_id, episode_id, method (coins|episode_pack|subscription), coins_spent, subscription_id nullable, timestamps; unique(user_id, episode_id)
- `watch_histories` id, user_id, drama_id, episode_id, progress_seconds, timestamps (unique user+drama, keeps last episode)
- `episode_views` id, episode_id, drama_id, company_id, user_id nullable, viewed_on DATE, timestamps (for stats)
- `favorites` user_id, drama_id
- `company_earnings` id, company_id, drama_id nullable, source (subscription_pool|episode_pack|coins), amount, period_date DATE, meta JSON, timestamps
- `payouts` id, company_id, amount, status (pending|paid), reference, paid_at, notes
- `settings` key/value (platform_name, support_email, default_currency…)

Revenue attribution:
- Coin / episode-pack unlocks → immediately create `company_earnings` = value of the unlock × company share %. (Episode-pack value per episode = plan price / episode_quota; coins value = coins_spent × coin TZS value from settings `coin_value_tzs`, default 10.)
- Time subscriptions (weekly/monthly/yearly) → artisan command `earnings:distribute {--date=}` (scheduled daily) pools the day's prorated subscription revenue × company share and splits by each company's share of subscriber views that day.

## 5. Payment gateway abstraction (NOT integrated yet, but pluggable)

`app/Payments/Contracts/PaymentGateway.php`:
```php
interface PaymentGateway {
  public function initiate(Payment $payment, array $data): GatewayResponse; // push USSD / redirect url
  public function verify(Payment $payment): GatewayResponse;
  public function handleCallback(Request $request): ?Payment;
}
```
Drivers in `app/Payments/Gateways/`: `MpesaGateway`, `TigoPesaGateway`, `AirtelMoneyGateway`, `HaloPesaGateway`, `CardGateway` (Visa/Mastercard — e.g. via DPO/Flutterwave/Selcom), `BankGateway`, plus `SandboxGateway`. Non-integrated drivers return `GatewayResponse::pending('Provider not yet connected')`. `PaymentManager` resolves driver by method code from `config/payments.php` (keys read from `.env`, e.g. `MPESA_API_KEY`…). Setting `PAYMENTS_SANDBOX_AUTO_APPROVE=true` makes the sandbox mark payments successful immediately so the flow can be demoed end-to-end. On success → `PaymentService::fulfill()` creates subscription / adds coins / episode quota.

## 6. REST API (`/api/v1`, JSON, Sanctum bearer tokens)

Response envelope: `{ "data": ..., "meta": {...}? }`; errors: `{ "message": "...", "code": "snake_case", "errors": {...}? }` with proper HTTP status.

Drama JSON:
```json
{ "id":1,"slug":"the-chiefs-daughter","title":"...","synopsis":"...","poster_url":"...","backdrop_url":"...",
  "total_episodes":60,"free_episodes":5,"coins_per_episode":30,"badge":"hot","views":1250000,
  "categories":[{"id":1,"name":"Romance","slug":"romance"}],"tags":["Billionaire","Secret Identity"],
  "company":{"id":1,"name":"Kilima Studios","slug":"kilima-studios"},"is_favorite":false }
```
Episode JSON: `{ "id", "number", "title", "duration_seconds", "thumbnail_url", "is_free", "is_unlocked" }` (`video_url` only from play endpoint).

Public / viewer:
- `POST /auth/register` {name, email?|phone?, password} → `{data:{token,user}}`
- `POST /auth/login` {login (email or phone), password} → `{data:{token,user}}`
- `POST /auth/logout`, `GET /auth/me` → user incl. `coins`, `role`, `company`, `active_subscription`
- `GET /home` → `{data:{banners:[Drama], sections:[{key,title,layout:"row"|"ranking"|"grid",dramas:[Drama]}]}}`
- `GET /categories`
- `GET /dramas?category=slug&q=&sort=popular|newest&page=&per_page=` → paginated (`meta:{current_page,last_page,total}`)
- `GET /dramas/rankings?type=trending|new|popular`
- `GET /dramas/{slug}` → Drama + `episodes:[Episode]` + `related:[Drama]`
- `GET /feed` → For-You list `[ {drama, episode(ep1 with video_url)} ]`
- `GET /episodes/{id}/play` (auth optional) → `{data:{video_url, episode, next_episode_id, prev_episode_id}}` or **402** `{code:"episode_locked", message, unlock:{coins_required, user_coins, can_use_pack}}`
- `POST /episodes/{id}/unlock` {method: coins|episode_pack} (auth)
- `POST /episodes/{id}/progress` {progress_seconds} (auth)
- `GET /plans`, `GET /payment-methods`
- `POST /checkout` {plan_id, payment_method, phone?, card?:{...ignored}} (auth) → `{data:{payment:{reference,status,amount,currency}, message, next_action:"await_ussd"|"redirect"|"none", redirect_url?}}`
- `GET /payments/{reference}` (auth) → status polling
- `POST /payments/callback/{provider}` (public webhook)
- `GET /me/subscription`, `GET /me/payments`, `GET /me/history`, `GET /me/favorites`, `POST /me/favorites/{drama_id}` (toggle)

Super admin (`role:super_admin`) prefix `/admin`:
- `GET /admin/dashboard` → totals (revenue, revenue today/month, users, active subscribers, companies, dramas, views), `revenue_chart` (last 30 days), `top_dramas`, `recent_payments`, `revenue_by_method`
- CRUD `/admin/companies` (create also creates the company's login user: owner_name, owner_email, owner_password), `/admin/companies/{id}/stats`
- CRUD `/admin/plans`, `/admin/categories`, `/admin/dramas` (+ `/admin/dramas/{id}/episodes`), `GET/PUT /admin/payment-methods/{id}` (enable/disable, integrated flag, config)
- `GET /admin/users` (filter role, search), `PUT /admin/users/{id}` (status, coins adjust, role)
- `GET /admin/payments` (filters), `GET/POST /admin/payouts`, `PUT /admin/payouts/{id}`
- `GET/PUT /admin/settings`

Company studio (`role:company`) prefix `/studio`:
- `GET /studio/dashboard` → views (total/today/30d), unique watchers, earnings (total/month/pending payout), `views_chart`, `earnings_chart` (30d), per-drama table (views, episodes, earnings)
- CRUD `/studio/dramas`, CRUD `/studio/dramas/{id}/episodes` (video_url or multipart `video` file upload to `storage/app/public/videos`; poster upload too)
- `GET /studio/earnings`, `GET /studio/payouts`, `GET/PUT /studio/profile`

## 7. Seed data

- Super admin: `admin@afriva.com` / `password`
- Companies (each with login `<slug>@afriva.com` / `password`): Kilima Studios (TZ), Savannah Pictures (KE), Lagos Reel House (NG), Zanzibar Tales (TZ)
- Viewer: `viewer@afriva.com` / `password` (200 coins), and a VIP viewer `vip@afriva.com` / `password` with active monthly sub.
- ~32 ORIGINAL dramas with original African-set titles & synopses (e.g. "The Chief's Hidden Heir", "Married to the Mogul of Masaki", "Bride of Kilimanjaro", "Revenge of the Maasai Princess", "My CEO is a Fisherman", "Love in Stone Town", "Second Wife, First Love", "The Billionaire's Village Girl"...), 20–80 episodes each, spread across categories, badges, view counts.
- Posters: `https://picsum.photos/seed/afriva-<slug>/600/800`, backdrops `https://picsum.photos/seed/afriva-<slug>-bg/1280/720`.
- Video URLs (public sample MP4s, rotate): 
  - https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4
  - https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4
  - https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4
  - https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4
  - https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4
- Plans: Weekly VIP 3,000 TZS (7d) · Monthly VIP 10,000 TZS (30d, popular) · Yearly VIP 90,000 TZS (365d) · 6 Episodes 10,000 TZS · 15 Episodes 20,000 TZS · 100 Coins 1,000 TZS · 550 Coins (+50 bonus) 5,000 TZS.
- Payment methods: M-Pesa, Mixx by Yas (Tigo Pesa), Airtel Money, HaloPesa, T-Pesa, Visa, Mastercard, CRDB, NMB, NBC — all enabled, none integrated.
- ~60 days of synthetic episode_views, payments, subscriptions and company_earnings so dashboards have charts.
