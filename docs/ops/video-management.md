# Video management (Bunny Stream)

Episode videos never pass through the Afriva server. Laravel only creates videos in Bunny, hands out short-lived upload permissions, tracks status and signs playback URLs. Code: `backend/app/Services/BunnyStream.php`.

## Settings

| Variable | Where in Bunny | Purpose |
|---|---|---|
| `BUNNY_STREAM_LIBRARY_ID` | Stream > library > API | Which library holds Afriva's videos. |
| `BUNNY_STREAM_API_KEY` | Stream > library > API | Create, read and delete videos. Server only. |
| `BUNNY_STREAM_CDN_HOSTNAME` | Stream > library > API > CDN hostname (`vz-....b-cdn.net`) | Playback host. |
| `BUNNY_STREAM_TOKEN_KEY` | Library > Security > CDN token authentication | Signs playback URLs. Set it in production. |
| `BUNNY_STREAM_TOKEN_TTL` | n/a | Signed URL lifetime, default 14400 s (4 h). |
| `BUNNY_STREAM_WEBHOOK_SECRET` | Library > API > Read-Only API key | When set, webhooks without a valid signature are ignored. Set it in production. |
| `BUNNY_STREAM_PROTECTED_VIDEOS` | n/a | Comma separated video ids that are never deleted (shared demo videos). |
| `BUNNY_STREAM_SHOWCASE_VIDEO` | n/a | Video used by the showcase seed data. |
| `MEDIA_CDN_URL` | Bunny pull zone (`afrivamedia.b-cdn.net`) | Optional CDN in front of public images (until images move to R2). |
| `BUNNY_ACCOUNT_API_KEY` | Account > API | Account-wide figures for the admin Infrastructure page. Full account access: server only. |

## Upload flow (admin and studio)

1. The admin or studio page calls `POST /api/v1/admin/dramas/{drama}/episodes/{episode}/video-upload` (or the `studio/` equivalent). Rate limit: 30 per minute.
2. Laravel creates a video object in Bunny (`createVideo`), stores its id in `episodes.bunny_video_id`, sets the episode to `uploading`, and returns TUS credentials: the Bunny TUS endpoint `https://video.bunnycdn.com/tusupload`, library id, video id, an expiry 6 hours ahead and a signature `sha256(library_id + api_key + expiry + video_id)`. The API key itself never leaves the server.
3. The browser uploads the file straight to Bunny with `tus-js-client` (resumable; survives weak connections).
4. Bunny encodes the video into HLS renditions.

Because video bytes go to Bunny, Nginx's `client_max_body_size` (25 MB) only has to fit images.

## Status updates

* **Webhook:** Bunny posts to `POST https://api.afriva.co.tz/api/v1/webhooks/bunny` on every state change. In Bunny: library > API > Webhook URL. The controller checks the `X-BunnyStream-Signature` (v1, HMAC-SHA256 of the raw body with the Read-Only API key) when `BUNNY_STREAM_WEBHOOK_SECRET` is set, ignores other libraries and non-encoding events, always answers 200 at once, and then reads the true state with Bunny's Get Video API after the response is sent. Rate limit: 300 per minute.
* **Fallback sync:** the scheduler runs `php artisan bunny:sync` every 5 minutes. It re-checks episodes still `uploading` or `processing` (untouched for 2+ minutes) and gives up on uploads that never received a file within the TUS window.
* Run by hand: `compose.sh exec app php artisan bunny:sync`.

## Playback

* `GET /api/v1/episodes/{id}/play` returns the HLS playlist `https://{cdn_hostname}/{video_id}/playlist.m3u8`.
* With `BUNNY_STREAM_TOKEN_KEY` set, the URL carries an expiring token (Bunny "Advanced" HS256 token authentication, path-based, covering every segment under `/{video_id}/`). Links stop working after the TTL, which stops casual sharing. It is not DRM; see the security note in the deployment plan.
* Web uses hls.js; the Flutter app plays the same HLS URL with a quality picker.

## Deletion

* Deleting an episode or drama deletes its Bunny videos (`deleteVideo` / `deleteVideos`), except ids listed in `BUNNY_STREAM_PROTECTED_VIDEOS`.
* Replacing a video creates a new Bunny video and cleans up the old one.
* Deleting in the Bunny dashboard by hand leaves the episode pointing at a missing video; avoid it, or clear the episode's video in admin afterwards.

## Cloudflare and Bunny together

* `api.afriva.co.tz` is proxied by Cloudflare. Bunny's webhook calls reach it through Cloudflare like any client. If Cloudflare's WAF or "Bot Fight Mode" ever challenges them, add a WAF skip rule for the path `/api/v1/webhooks/bunny`.
* Bunny CDN hostnames (`vz-....b-cdn.net`, `afrivamedia.b-cdn.net`) and `video.bunnycdn.com` are Bunny's own domains, not records in the `afriva.co.tz` zone, so Cloudflare does not proxy or change video traffic. Uploads and playback go straight from users to Bunny.
* If you later add a custom hostname for video (for example `video.afriva.co.tz` as a CNAME to Bunny), set it to **DNS only (grey)** in Cloudflare so the two CDNs are not stacked.

## Costs and limits

Bunny bills storage per GB per region and delivery per GB (Africa costs more than Europe); encoding is included. Bunny uses a prepaid balance: there is no hard spend cap, and streaming stops if the balance runs out. Turn on low-balance email alerts and consider auto-recharge. See [costs.md](costs.md).

## Common problems

| Symptom | Check |
|---|---|
| Upload stuck at "uploading" | Browser console for TUS errors; `bunny:sync` gives up after the 6 h window. |
| Stuck at "processing" | Bunny dashboard encoding status; webhook URL set; `compose.sh logs app \| grep -i bunny`. |
| Webhook "invalid signature" in logs | `BUNNY_STREAM_WEBHOOK_SECRET` must be the library's **Read-Only** API key. |
| Playback 403 | `BUNNY_STREAM_TOKEN_KEY` matches the library; server clock correct (`timedatectl`). |
