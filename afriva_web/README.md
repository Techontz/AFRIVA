# Afriva Web

Next.js front-end for **Afriva**, a short-drama streaming platform for African audiences. One app serves three experiences:

| Area | Path | Who |
|---|---|---|
| Viewer site | `/`, `/foryou` (via avatar menu), `/browse`, `/rankings`, `/drama/[slug]`, `/drama/[slug]/ep/[n]`, `/vip`, `/search`, `/account`, `/login`, `/register`, `/app`, `/info/*` | everyone |
| Super Admin portal | `/admin/*` | `super_admin` |
| Studio portal | `/studio/*` | `company` |

The API is the Laravel app in `../backend`, served at `http://localhost:8000/api/v1`. The contract is `../SPEC.md` §6.

## Stack

- Next.js 16 (App Router, Cache Components), React 19, TypeScript, Tailwind CSS v4
- Plus Jakarta Sans via `next/font/google`
- `recharts` for dashboard charts and `sonner` for toasts. Icons are inline SVG.

## Setup

```bash
cp .env.example .env.local      # NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
npm install
npm run dev                     # http://localhost:3000
```

Production build:

```bash
npm run build && npm start
npm run lint
```

Start the backend first (`cd ../backend && php artisan serve`). If the API is down, public pages still render and show a "can't reach Afriva" state instead of crashing.

## Seeded accounts

All accounts use the password `password`.

| Role | Login | Lands on |
|---|---|---|
| Super admin | `admin@afriva.com` | `/admin` |
| Studio (Kilima Studios) | `kilima-studios@afriva.com` | `/studio` |
| Other studios | `savannah-pictures@afriva.com`, `lagos-reel-house@afriva.com`, `zanzibar-tales@afriva.com` | `/studio` |
| Viewer (200 coins) | `viewer@afriva.com` | `/` |
| VIP viewer | `vip@afriva.com` | `/` |

## How it works

- **Data fetching.** Public pages are server components. They call `src/lib/server-api.ts` inside `<Suspense>` with a skeleton fallback. Fetches run at request time (`connection()`), and successful responses are cached for 60–300 s through `fetch(..., { next: { revalidate } })`. Failures return `null`, and the page shows an empty or error state. This way a build made while the API is offline never ships empty pages.
- **Auth.** `POST /auth/login` returns a Sanctum token. It is stored in `localStorage` and in an `afriva_token` cookie. `AuthProvider` (`src/lib/auth.tsx`) loads `/auth/me` and exposes `useAuth()`. A 401 from the API signs the user out.
- **Route guards.** `RoleGuard` runs on the client and is used by the `/admin`, `/studio` and `/account` layouts. Login sends admins to `/admin`, studios to `/studio`, and viewers to `?next=` or `/`.
- **Client API.** `src/lib/api.ts` provides `api.get/post/put/del/page` and an `ApiError` with `status`, `code`, `errors` and `body`. Multipart `PUT` is sent as `POST` with `_method=PUT`, the Laravel convention. `src/lib/hooks.ts` provides `useApi` and `useList`, which accept both paginated and plain list responses.
- **Watch page.** The player is a vertical 9:16 HTML5 video. The episode panel is split into ranges of 30 episodes. It has prev/next buttons, N/P keyboard shortcuts and autoplay-next (the setting is remembered). Progress is saved to `/episodes/{id}/progress`. A `402 episode_locked` response opens the paywall, which offers "Subscribe VIP", "Unlock for N coins" and, when available, "Use my episode pack".
- **VIP checkout.** Plans are grouped as VIP, episode packs and coins. Payment methods are grouped as Mobile Money, Cards and Bank. Mobile money asks for a phone number, cards show a card form, and bank shows a bank form. The page calls `POST /checkout`, shows a pending or success state, and polls `GET /payments/{reference}` while the payment is pending.

## Project layout

```
src/
  app/
    (site)/        viewer pages (shared header/footer layout)
    admin/         super admin portal
    studio/        company portal
    not-found.tsx  branded 404
  components/
    ui/            Button, Form controls, Modal, Feedback (skeleton/empty/pills), Icon, Logo
    site/          Header, Footer, HeroCarousel, PosterCard, DramaRow, RankingList, EpisodeGrid, WatchPlayer, VipCheckout, AccountView…
    portal/        PortalShell (sidebar), Kit (cards/tables/pagination), Charts, MediaInput
    admin/, studio/  portal-specific helpers and forms
  lib/             api client, server fetch, auth context, hooks, types, formatters
```

## Design tokens

The brand is white, red and black. Tokens live in `src/app/globals.css` under `@theme`:

| Token | Value | Tailwind |
|---|---|---|
| bg | `#000000` | `bg-bg` |
| surface / surface-2 | `#111111` / `#1A1A1A` | `bg-surface`, `bg-surface-2` |
| border | `#262626` | `border-border` |
| text / muted / dim | `#FFFFFF` / `#B3B3B3` / `#737373` | `text-text`, `text-text-muted`, `text-text-dim` |
| primary (red) / hover | `#E1122B` / `#B80E22` | `bg-primary`, `hover:bg-primary-hover`, `text-primary` |
| brand gradient | `linear-gradient(135deg,#E1122B,#8B0A1A)` | `bg-brand`, `text-brand` |

Those are the dark defaults used by `/admin` and `/studio`. The public site (`src/app/(site)/layout.tsx`) wraps everything in `.site-light`, which redefines the same tokens for a light page (bg `#FFFFFF`, surface `#F2F2F2`, surface-2 `#E4E4E4`, text `#1A1A1A` / `#555` / `#888`). Header, footer, the video player and the For You feed use `.chrome-dark` (bg `#2B2B2B`). Page width comes from the `site-container` utility (max 1680px, up to 160px side padding).

The logo is a red rounded-square app icon with a white play mark next to the "Afriva" wordmark (`src/components/ui/Logo.tsx`).
