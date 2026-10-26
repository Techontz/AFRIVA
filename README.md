# Afriva

Short-drama streaming platform.

| Folder | Stack | What it is |
|---|---|---|
| [`afriva_web/`](afriva_web/) | Next.js | Viewer website, Admin dashboard (`/admin`, staff roles), Creator Studio (`/studio`) |
| [`backend/`](backend/) | Laravel + MySQL | REST API (`/api/v1`), payments, earnings |
| [`afriva_app/`](afriva_app/) | Flutter | Android / iOS app (viewer + "Wasilisha Kazi Yako" creator studio) |

See [`SPEC.md`](SPEC.md) for the API contract and data model (§8 covers the 2026 project scope: Kiswahili UI, 8 free episodes, creator review workflow, staff roles, HLS video, payments and analytics), and each folder's README for local setup.

## Deploying the website to Vercel

1. Import this repo in Vercel and set **Root Directory** to `afriva_web`.
2. Add the environment variable `NEXT_PUBLIC_API_URL` = `https://<your-backend-domain>/api/v1`.
3. The Laravel backend must be hosted separately (VPS, Laravel Forge/Cloud, Railway, etc.) with MySQL. Add the Vercel domain to `CORS_ALLOWED_ORIGINS` in the backend `.env`.
