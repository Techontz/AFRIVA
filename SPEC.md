# AFRIVA: Platform Spec (shared contract)

Afriva is a short-drama streaming platform (vertical, episodic mini-series) for African audiences.
Three apps share ONE API:

| Part | Path | Stack | Dev URL |
|---|---|---|---|
| Backend API | `backend/` | Laravel 11+, Sanctum, MySQL | http://localhost:8000 |
| Web (viewer site + Super Admin + Studio portal) | `afriva_web/` | Next.js (App Router, TypeScript, Tailwind) | http://localhost:3000 |
| Mobile app | `afriva_app/` | Flutter | - |

Currency default: **TZS**. All money stored as integer minor-less amounts (TZS has no decimals) in `amount` columns (BIGINT).

---

## 1. Brand & design system (use identically in web and app)

Original Afriva identity. Do NOT copy any third-party logo, artwork or copy.

- Theme: dark, cinematic.
  - `bg` #0B0B0F, `surface` #15151C, `surface-2` #1E1E28, `border` #2A2A36
  - `text` #FFFFFF, `text-muted` #A1A1B5, `text-dim` #6B6B80
  - `primary` #FF4D2E (Afriva coral), `primary-2` #FF8A00 (amber) → brand gradient `linear-gradient(135deg,#FF4D2E,#FF8A00)`
  - `gold` #F5C044 (VIP / coins), `success` #22C55E, `danger` #EF4444
- Font: **Plus Jakarta Sans** (Google Fonts): 400/500/600/700/800. Headings 700–800, tight letter-spacing.
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
- VIP / Subscribe `/vip`: plan cards from `/plans` (weekly, monthly, yearly, episode packs e.g. "6 episodes – 10,000 TZS", coin packs), then payment-method picker grouped: **Mobile Money** (M-Pesa, Tigo Pesa / Mixx by Yas, Airtel Money, HaloPesa, T-Pesa), **Cards** (Visa, Mastercard), **Bank** (CRDB, NMB, NBC), showing phone input for mobile money / card form UI for cards. Submit calls checkout; shows "Pending: payment provider not yet connected" state.
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
- `companies` id, name, slug, logo_url, email, phone, country, revenue_share_percent (DECIMAL 5,2 default 70.00, company's share), status (active|suspended), description, timestamps
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
Drivers in `app/Payments/Gateways/`: `MpesaGateway`, `TigoPesaGateway`, `AirtelMoneyGateway`, `HaloPesaGateway`, `CardGateway` (Visa/Mastercard, e.g. via DPO/Flutterwave/Selcom), `BankGateway`, plus `SandboxGateway`. Non-integrated drivers return `GatewayResponse::pending('Provider not yet connected')`. `PaymentManager` resolves driver by method code from `config/payments.php` (keys read from `.env`, e.g. `MPESA_API_KEY`…). Setting `PAYMENTS_SANDBOX_AUTO_APPROVE=true` makes the sandbox mark payments successful immediately so the flow can be demoed end-to-end. On success → `PaymentService::fulfill()` creates subscription / adds coins / episode quota.

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
- Payment methods: M-Pesa, Mixx by Yas (Tigo Pesa), Airtel Money, HaloPesa, T-Pesa, Visa, Mastercard, CRDB, NMB, NBC: all enabled, none integrated.
- ~60 days of synthetic episode_views, payments, subscriptions and company_earnings so dashboards have charts.

---

## 8. Project Scope 2026 (AFRIVA_Project_Scope.pdf), what changed

These rules override anything above that conflicts with them.

### 8.1 Language
The whole user interface is **Kiswahili** (web site, Studio, Admin, mobile app). Series titles may be in any language. Kiswahili is the default; English remains only as an optional fallback in the language setting. API messages (`message`, validation `errors`) are Kiswahili (`APP_LOCALE=sw`, `backend/lang/sw/validation.php`).

### 8.2 Catalogue
- Categories: **Mapenzi, Historia, Siri na Mafumbo, Vita na Mashujaa, Vichekesho, Upelelezi, Maisha, Hadithi za Afrika**.
- Free preview: **episodes 1-8 free by default** (`settings.default_free_episodes`), changeable per series by staff.
- Drama JSON adds: `trailer_url` (signed if uploaded), `age_rating` (`all|7+|13+|16+|18+`), `access_mode` (`coins_or_vip` default | `vip_only` | `coins_only`), `total_duration_seconds` (detail), `resume` (continue watching). Admin/studio responses also include `review_status, review_notes, publish_at, is_scheduled, is_live, submitted_at, reviewed_at, rights_declared_at, episodes_count`.
- Episode JSON adds: `access` (`free|unlocked|locked`), `price_coins`, `vip_only`, `subtitle_url`; with video: `sources`.
- `GET /home` sections: `continue_watching` (layout `continue`, signed-in only; each drama has `resume: {episode_id|null, episode_number, progress_seconds, duration_seconds}`), `trending` ("Zinazovuma", ranking), `new_releases` ("Mpya"), `must_watch`, one row per category, `popular` (grid).
- Viewers only see series that are `status=published` + `review_status=approved` + `publish_at` null or past, and only `approved` episodes.

### 8.3 Player
`GET /episodes/{id}/play` → `{video_url, sources: [{quality:"auto"|"480p"|"720p"|"1080p", label, url, type:"hls"|"mp4"}], subtitle_url, resume_seconds, session_id, episode, drama, next_episode_id, prev_episode_id}`. `video_url` = `sources[0].url` (HLS master when transcoded; web uses hls.js unless the browser plays HLS natively). Quality selection = switch to another source and seek to the current position. Locked → 402 `episode_locked` with `unlock: {coins_required, user_coins, can_use_coins, can_use_pack, can_use_vip, vip_only, episodes_remaining, requires_login}`; unlocking a `vip_only` series with coins → 402 `vip_required`.

Player must: play/pause/seek/retry/resume (`resume_seconds`)/auto-next/quality selection/save progress (`POST /episodes/{id}/progress` every ~10 s and on pause/exit, signed-in only).

Analytics events: `POST /events` (auth optional, header `X-Device-Id: <stable random id ≥8 chars>`) body `{events:[{session_id, episode_id, type: start|heartbeat|pause|complete|error|quality, position_seconds, watched_seconds (since last event, ≤120), duration_seconds, quality?, error_code?}]}`. Send `start` on first frame, `heartbeat` every ~15 s while playing, `pause`, `complete` at the end, `error` on playback failure, `quality` on manual quality change.

### 8.4 Payments
- Launch methods: M-Pesa, Mixx by Yas (Tigo Pesa), Airtel Money, HaloPesa (Tanzania); Visa, Mastercard (international); `wallet` (off). Banks/T-Pesa exist but are disabled.
- `payment-methods` items add `is_available`. **Only `is_available` methods may be offered**; others are shown as "Inakuja hivi karibuni" and checkout returns 422 `method_unavailable`. A method becomes available only when staff mark it integrated after a live test (or while the demo sandbox auto-approves).
- `POST /checkout` accepts `Idempotency-Key` header (8-80 chars `[A-Za-z0-9_-]`); a retry returns the same payment (200).
- Coins only change through the ledger: `GET /me/coins` → `[ {amount, balance_after, type: purchase|bonus|unlock|admin_adjust|refund, description, episode, created_at} ]`, `meta.balance`.
- Receipts: `GET /me/payments/{reference}/receipt` → `{receipt_number, reference, provider_reference, status, issued_at, customer, item:{name,type,description,delivered}, payment_method:{code,name}, amount, refunded_amount, currency, seller}`.
- Payment JSON adds `receipt_number, fee_amount, refunded_amount, refunded_at`; status may be `refunded`.
- `POST /payments/callback/sandbox` only works while `PAYMENTS_SANDBOX_ENABLED` (defaults to the auto-approve flag).

### 8.5 Creators ("Wasilisha Kazi Yako")
- `POST /creator/apply {name, phone?, email?, country?, description?}` (signed-in viewer) → user becomes `role=company` with company `status=pending`. Pending creators can prepare drafts but not submit.
- `GET /studio/agreement` → `{version, text, accepted, accepted_at, revenue_share_percent, company_status}`; `POST /studio/agreement {accept:true}`.
- Review statuses (Kiswahili labels): `draft` Rasimu · `submitted` Imetumwa · `in_review` Inakaguliwa · `changes_requested` Marekebisho · `approved` Imeidhinishwa · `rejected` Imekataliwa.
- Creators cannot set publishing rules (status, publish_at, free_episodes, coins_per_episode, access_mode, badge, featured, release_date, is_free); they are ignored. Creators can edit a series/episode only in `draft` or `changes_requested` (else 409 `locked_for_review`); new episodes may be added to an approved series and go through review on their own.
- Studio drama form fields: `title, synopsis, category_ids[], tags, poster (file), backdrop (file), trailer (video file) | trailer_url, age_rating, language`. Episode: `number?, title, video (file) | video_url, thumbnail (file), subtitle (.vtt/.srt file), duration_seconds`.
- `POST /studio/dramas/{id}/submit {rights_declaration: true}` (requires active creator + accepted agreement + synopsis, poster, genre, ≥1 pending episode with video). `GET /studio/dramas/{id}` includes `episodes` (with `review_status, review_notes, video_status, sources`) and `reviews` (history with reviewer notes).
- `POST /studio/dramas/{id}/episodes/reorder {episode_ids:[...]}` (editable series only), `GET /studio/analytics?days=`, `GET /studio/dramas/{id}/analytics?days=`. Studio dashboard adds `company.status`, `company.agreement_accepted`, `review_counts`, and per drama `review_status`, `is_live`.
- Viewers report a series: `POST /dramas/{id}/report {reason: copyright|inappropriate|misleading|other, details (required for copyright), episode_id?, contact?}`.

### 8.6 Staff roles and admin API
`users.staff_role` for `role=super_admin`: **owner** (everything), **editor** (dashboard, content, publish, creators, reports, analytics), **reviewer** (dashboard, review, reports), **finance** (dashboard, finance, analytics). `GET /auth/me` returns `staff_role` and `permissions`; hide what the role cannot use (the API returns 403 anyway).

| Area (permission) | Endpoints |
|---|---|
| content | categories CRUD; `POST/PUT/DELETE /admin/dramas…`; `POST /admin/dramas/{id}/episodes/reorder`; `GET /admin/videos?video_status=&review_status=&unverified=1&q=` (Video Library, meta `counts`, `transcoding_enabled`); `POST /admin/videos/{episode}/reprocess` |
| content, review or publish | `GET /admin/dramas`, `/admin/dramas/{id}` (+ `reviews`), episodes (`?review_status=` filter on list) |
| publish | `POST /admin/dramas/{id}/publish {publish_at?, free_episodes?, coins_per_episode?, access_mode?, is_featured?, badge?}` (approved only; future `publish_at` = scheduled), `POST /admin/dramas/{id}/unpublish` |
| review | `GET /admin/reviews?status=pending|changes_requested|rejected|approved|all` (meta `counts`), `GET /admin/reviews/{drama}`, `POST /admin/reviews/{drama}/start`, `POST /admin/reviews/{drama}/decide {decision: approve|request_changes|reject, notes (required unless approve), episode_ids?}`, `POST /admin/episodes/{id}/verify-playback` (required for every episode before approval) |
| reports | `GET /admin/reports?status=open|resolved|dismissed|all`, `PUT /admin/reports/{id} {status, resolution_notes}` |
| creators | companies CRUD (status `pending|active|suspended`; list meta `pending`; approve = `PUT {status:"active"}`), stats |
| finance | plans, payment methods (`fee_percent`; set `is_integrated` only after a live test; `tested_at`), `GET /admin/payments`, `GET /admin/payments/{id}` (refunds, receipt, net), `POST /admin/payments/{id}/refund {amount?, reason}`, `GET /admin/coin-transactions?user_id=&type=`, payouts, `GET/POST /admin/costs {period: YYYY-MM, category: streaming|storage|hosting|payments|other, amount, notes}`, `DELETE /admin/costs/{id}` |
| analytics | `GET /admin/analytics?days=7|30|90|365` → `revenue{gross, refunds, fees, net, streaming_cost, streaming_cost_is_estimate, operating_costs, net_after_costs, by_type, chart[{date,gross,net}]}`, `audience{views, unique_viewers, watch_seconds, avg_watch_seconds_per_viewer, sessions, completion_rate, returning_viewers, retention_rate, playback_errors, views_chart, watch_time_chart}`, `active_users{dau, dau_avg, mau, chart}`, `coins{purchased, bonus, spent, refunded, admin_adjusted, outstanding_balance, chart[{date,bought,spent}]}`, `payments{attempts, success, failed, pending, cancelled, success_rate, by_method[]}`, `series[{drama_id,title,poster_url,revenue_gross,creator_earnings,views,unique_viewers,watch_seconds,completion_rate}]`, `alerts[]`; `GET /admin/analytics/dramas/{id}?days=` → per-episode `{views, unique_viewers, reach_rate, watch_seconds, completion_rate, avg_percent_watched, revenue_gross, is_free}` + `drop_off[10 buckets]` |
| users | users list/update (`coins_adjust` + `coins_reason` go through the ledger; role only viewer/company) |
| settings | settings (adds `default_free_episodes, default_coins_per_episode, streaming_avg_kbps, streaming_cost_per_gb_tzs, cost_alert_monthly_tzs, creator_agreement_version, creator_agreement_text`) |
| staff | `GET /admin/staff` (meta `roles` with permissions), `POST /admin/staff {name,email,password,staff_role}`, `PUT /admin/staff/{id} {staff_role?, status?, name?, password?}` (the last active owner cannot be removed) |
| audit | `GET /admin/audit-logs?action=&user_id=&subject_type=` |

Admin navigation (Kiswahili): **Muhtasari · Ukaguzi · Series na Episodes · Video Library · Creators · Miamala · Analytics · Ripoti · Watumiaji · Mipangilio** (+ Mipango, Njia za malipo, Malipo kwa creators, Wafanyakazi, Kumbukumbu/Audit log), each shown only with the matching permission.

### 8.7 Video pipeline
Uploads go to the private `videos` disk. With `MEDIA_TRANSCODE=true` (needs ffmpeg/ffprobe), a queued job encodes HLS 480p/720p/1080p (never above the source), writes `hls/<episode>/master.m3u8`, sets duration and a thumbnail; episode `video_status`: `processing → ready | failed` (`video_error`). Without transcoding the file is served as-is (`ready`). Playlists are rewritten so every segment URL is signed and expiring. Replacing a creator's video resets `playback_verified_at`. Trimming/cropping is not done on the server.

### 8.8 Seed data (local only)
Staff demo logins: `admin@afriva.com` (owner), `editor@afriva.com`, `reviewer@afriva.com`, `finance@afriva.com`, all `password`. Plans are named in Kiswahili (VIP ya Wiki/Mwezi/Mwaka, Episode 6/15, Coins 100/550). `ActivitySeeder` creates synthetic history for local demos only; production seeds only `CoreSeeder`, so every dashboard number there comes from real activity.
