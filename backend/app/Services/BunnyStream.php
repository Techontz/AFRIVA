<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\ApplicationSample;
use App\Models\Episode;
use App\Support\CatalogCache;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Bunny Stream integration (https://bunny.net/docs/stream).
 *
 * - Create / Get / Delete Video: https://video.bunnycdn.com/library/{libraryId}/videos[/{videoId}], header AccessKey.
 * - TUS upload signature: sha256(library_id + api_key + expiration_time + video_id).
 * - Playback: HLS playlist at https://{cdn_hostname}/{guid}/playlist.m3u8, signed with Advanced (HS256) CDN token
 *   authentication as a path-based directory token so every segment under /{guid}/ is covered.
 */
class BunnyStream
{
    public const TUS_ENDPOINT = 'https://video.bunnycdn.com/tusupload';

    public const API_BASE = 'https://video.bunnycdn.com';

    /** Upload signatures stay valid this long (Bunny checks the expiry on every TUS request). */
    public const UPLOAD_TTL = 6 * 3600;

    // Get Video "status" (VideoModelStatus in the Stream OpenAPI). Note: webhook status codes are different.
    public const STATUS_CREATED = 0;

    public const STATUS_UPLOADED = 1;

    public const STATUS_PROCESSING = 2;

    public const STATUS_TRANSCODING = 3;

    public const STATUS_FINISHED = 4;

    public const STATUS_ERROR = 5;

    public const STATUS_UPLOAD_FAILED = 6;

    public const STATUS_JIT_SEGMENTING = 7;

    public const STATUS_JIT_PLAYLISTS_CREATED = 8;

    protected const GUID_PATTERN = '/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i';

    public function enabled(): bool
    {
        return filled($this->libraryId()) && filled($this->apiKey()) && filled($this->cdnHostname());
    }

    public function libraryId(): string
    {
        return trim((string) config('services.bunny.library_id'));
    }

    protected function apiKey(): string
    {
        return (string) config('services.bunny.api_key');
    }

    public function cdnHostname(): string
    {
        $host = trim((string) config('services.bunny.cdn_hostname'));
        $host = preg_replace('#^https?://#i', '', $host);

        return strtolower(rtrim((string) $host, '/'));
    }

    protected function tokenKey(): string
    {
        return (string) config('services.bunny.token_auth_key');
    }

    protected function tokenTtl(): int
    {
        return max(60, (int) config('services.bunny.token_ttl', 14400));
    }

    public function ensureEnabled(): void
    {
        if (! $this->enabled()) {
            throw new ApiException(__('api.video_storage_not_configured'), 'video_storage_not_configured', 503);
        }
    }

    protected function api(): PendingRequest
    {
        return Http::baseUrl(self::API_BASE.'/library/'.rawurlencode($this->libraryId()))
            ->withHeaders(['AccessKey' => $this->apiKey()])
            ->acceptJson()
            ->connectTimeout(5)
            ->timeout(15);
    }

    // ---- Stream API -------------------------------------------------------

    /** POST /library/{id}/videos {title} → VideoModel (guid, ...). */
    public function createVideo(string $title): array
    {
        try {
            $video = $this->api()->post('/videos', ['title' => $title])->throw()->json();
        } catch (Throwable $e) {
            Log::warning('Bunny create video failed', ['error' => $e->getMessage()]);
            throw new ApiException(__('api.video_storage_error'), 'video_storage_error', 502);
        }
        if (! is_array($video) || empty($video['guid'])) {
            Log::warning('Bunny create video returned no guid');
            throw new ApiException(__('api.video_storage_error'), 'video_storage_error', 502);
        }

        return $video;
    }

    /** GET /library/{id}/videos/{guid}. Returns null when Bunny says 404; throws on other failures. */
    public function getVideo(string $guid): ?array
    {
        $response = $this->api()->get('/videos/'.rawurlencode($guid));
        if ($response->status() === 404) {
            return null;
        }
        $response->throw();

        return $response->json();
    }

    /** DELETE /library/{id}/videos/{guid}. Best effort: never throws, logs failures. */
    public function deleteVideo(?string $guid): bool
    {
        if (! $guid || ! $this->enabled() || in_array($guid, (array) config('services.bunny.protected_videos'), true)) {
            return false;
        }
        try {
            $response = $this->api()->delete('/videos/'.rawurlencode($guid));
            if ($response->successful() || $response->status() === 404) {
                return true;
            }
            Log::warning('Bunny delete video failed', ['video_id' => $guid, 'status' => $response->status()]);
        } catch (Throwable $e) {
            Log::warning('Bunny delete video failed', ['video_id' => $guid, 'error' => $e->getMessage()]);
        }

        return false;
    }

    /** @param  iterable<string|null>  $guids */
    public function deleteVideos(iterable $guids): void
    {
        foreach (collect($guids)->filter()->unique() as $guid) {
            $this->deleteVideo($guid);
        }
    }

    // ---- Uploads ------------------------------------------------------------

    /** TUS upload credentials for the client. Never contains the API key. */
    public function uploadCredentials(string $guid, string $title): array
    {
        $expires = time() + self::UPLOAD_TTL;

        return [
            'video_id' => $guid,
            'library_id' => $this->libraryId(),
            'tus_endpoint' => self::TUS_ENDPOINT,
            'signature' => hash('sha256', $this->libraryId().$this->apiKey().$expires.$guid),
            'expires' => $expires,
            'title' => $title,
        ];
    }

    // ---- URLs -------------------------------------------------------------

    public function playlistUrl(string $guid): string
    {
        return 'https://'.$this->cdnHostname().'/'.$guid.'/playlist.m3u8';
    }

    /** The Bunny video guid a URL on our library's CDN host points to (https://{cdn}/{guid}/...), or null. */
    public function guidFromUrl(?string $url): ?string
    {
        if (! $url || ! $this->cdnHostname()) {
            return null;
        }
        if (! $this->isCdnUrl($url)) {
            return null;
        }
        $parts = parse_url((string) $this->unsignUrl($url));
        $segment = explode('/', ltrim($parts['path'] ?? '', '/'))[0] ?? '';

        return preg_match(self::GUID_PATTERN, $segment) ? $segment : null;
    }

    /**
     * Playable URL for a viewer who is allowed to watch the episode (access must be checked by the caller).
     * null = "coming soon" (no video yet). Bunny URLs are signed when token authentication is configured.
     * Never store the result in CatalogCache.
     */
    public function playbackUrl(Episode $episode): ?string
    {
        $url = $episode->video_url;
        if (blank($url)) {
            return null;
        }
        $guid = $this->guidFromUrl($url);
        if (! $guid || $this->tokenKey() === '') {
            return $url;
        }
        $url = $this->unsignUrl($url);

        return $this->signDirectoryUrl($url, '/'.$guid.'/', time() + $this->tokenTtl());
    }

    /** Signed HLS playlist for a Bunny video guid (used for admin-only previews such as application samples). */
    public function signedPlaylistUrl(string $guid): string
    {
        $url = $this->playlistUrl($guid);
        if ($this->tokenKey() === '') {
            return $url;
        }

        return $this->signDirectoryUrl($url, '/'.$guid.'/', time() + $this->tokenTtl());
    }

    /** True when the URL points at our library's CDN hostname. */
    public function isCdnUrl(?string $url): bool
    {
        if (blank($url) || ! $this->cdnHostname()) {
            return false;
        }

        return strtolower((string) parse_url($url, PHP_URL_HOST)) === $this->cdnHostname();
    }

    /**
     * Thumbnails, posters and other single files on the library CDN host get a query string token when token
     * auth is on. The expiry is bucketed (end of the current 7 day window + 7 days, so 7 to 14 days left), which
     * keeps the URL identical for a whole week: cacheable by clients and safe inside CatalogCache.
     */
    public function signAssetUrl(?string $url): ?string
    {
        $url = $this->toMediaCdn($url);
        if (blank($url) || $this->tokenKey() === '' || ! $this->isCdnUrl($url)) {
            return $url;
        }
        $url = $this->unsignUrl($url);
        $week = 7 * 86400;
        $expires = (intdiv(time(), $week) + 2) * $week;

        return $this->signFileUrl($url, $expires);
    }

    /** Files served from this API (posters, uploads) go out through the media pull zone when one is configured. */
    public function toMediaCdn(?string $url): ?string
    {
        $cdn = rtrim((string) config('services.bunny.media_cdn_url'), '/');
        $origin = rtrim((string) config('app.url'), '/');
        if (blank($url) || $cdn === '' || $origin === '' || ! str_starts_with($url, $origin.'/')) {
            return $url;
        }

        return $cdn.substr($url, strlen($origin));
    }

    /** Inverse of toMediaCdn, so URLs echoed back by clients are stored against this API's own origin. */
    public function fromMediaCdn(?string $url): ?string
    {
        $cdn = rtrim((string) config('services.bunny.media_cdn_url'), '/');
        if (blank($url) || $cdn === '' || ! str_starts_with($url, $cdn.'/')) {
            return $url;
        }

        return rtrim((string) config('app.url'), '/').substr($url, strlen($cdn));
    }

    /**
     * Strips our CDN tokens from a URL (path based "/bcdn_token=...&expires=N/..." or "?token=..&expires=..")
     * so signed URLs echoed back by clients are stored raw.
     */
    public function unsignUrl(?string $url): ?string
    {
        $url = $this->fromMediaCdn($url);
        if (blank($url) || ! $this->isCdnUrl($url)) {
            return $url;
        }
        $parts = parse_url($url);
        $path = $parts['path'] ?? '/';
        if (preg_match('#^/bcdn_token=[^/]*(/.*)$#', $path, $m)) {
            $path = $m[1];
        }
        $query = '';
        if (! empty($parts['query'])) {
            parse_str($parts['query'], $params);
            unset($params['token'], $params['expires'], $params['token_path']);
            $query = $params ? '?'.http_build_query($params) : '';
        }

        return 'https://'.$parts['host'].$path.$query;
    }

    /**
     * Advanced token authentication, path-based directory token (required for HLS so segments inherit it):
     * token = "HS256-" + base64url(HMAC-SHA256(key, token_path + expires + "token_path=" + token_path))
     * url   = https://host/bcdn_token={token}&token_path={urlencoded}&expires={expires}{path}
     */
    public function signDirectoryUrl(string $url, string $tokenPath, int $expires): string
    {
        $parts = parse_url($url);
        $path = $parts['path'] ?? '/';
        $signingData = 'token_path='.$tokenPath;
        $token = $this->hs256Token($tokenPath.$expires.$signingData);

        return 'https://'.$parts['host'].'/bcdn_token='.$token.'&token_path='.rawurlencode($tokenPath).'&expires='.$expires.$path;
    }

    /** Advanced token authentication, query string form for a single file. */
    public function signFileUrl(string $url, int $expires): string
    {
        $parts = parse_url($url);
        $path = $parts['path'] ?? '/';
        $token = $this->hs256Token($path.$expires);

        return 'https://'.$parts['host'].$path.'?token='.$token.'&expires='.$expires;
    }

    protected function hs256Token(string $message): string
    {
        $digest = hash_hmac('sha256', $message, $this->tokenKey(), true);

        return 'HS256-'.rtrim(strtr(base64_encode($digest), '+/', '-_'), '=');
    }

    // ---- Webhook signature (optional) ---------------------------------------

    /** v1 signature: lowercase hex HMAC-SHA256 of the raw body keyed with the library's Read-Only API key. */
    public function validWebhookSignature(string $rawBody, ?string $signature, ?string $version, ?string $algorithm): bool
    {
        $secret = (string) config('services.bunny.webhook_secret');
        if ($secret === '') {
            return true;
        }
        if ($version !== 'v1' || $algorithm !== 'hmac-sha256' || ! $signature) {
            return false;
        }

        return hash_equals(hash_hmac('sha256', $rawBody, $secret), strtolower($signature));
    }

    // ---- Status sync ------------------------------------------------------

    /**
     * Read the real state from Bunny (Get Video) and apply it to the episode. Returns the resulting
     * video_status, or null when Bunny could not be reached (left unchanged, retried by bunny:sync).
     */
    public function syncEpisode(Episode $episode): ?string
    {
        $guid = $episode->bunny_video_id;
        if (! $guid || ! $this->enabled()) {
            return null;
        }
        try {
            $video = $this->getVideo($guid);
        } catch (RequestException|Throwable $e) {
            Log::warning('Bunny get video failed', ['video_id' => $guid, 'error' => $e->getMessage()]);

            return null;
        }

        return $this->applyVideo($episode, $video);
    }

    /** @param  array|null  $video  Get Video response, or null if Bunny returned 404 */
    public function applyVideo(Episode $episode, ?array $video): string
    {
        $guid = (string) $episode->bunny_video_id;

        if ($video === null) {
            // The video no longer exists at Bunny: the upload can never finish.
            if (in_array($episode->video_status, ['uploading', 'processing'], true)) {
                $episode->video_status = 'failed';
            }
            if ($this->guidFromUrl($episode->video_url) === $guid) {
                $episode->video_url = null;
                $episode->video_status = 'failed';
            }

            return $this->persist($episode);
        }

        if (strcasecmp((string) ($video['guid'] ?? ''), $guid) !== 0) {
            return (string) $episode->video_status;
        }

        $status = (int) ($video['status'] ?? -1);
        $hasResolution = filled($video['availableResolutions'] ?? null);
        $playable = $status === self::STATUS_FINISHED
            || ($hasResolution && in_array($status, [self::STATUS_PROCESSING, self::STATUS_TRANSCODING, self::STATUS_JIT_SEGMENTING, self::STATUS_JIT_PLAYLISTS_CREATED], true));

        if ($playable) {
            $replaced = $this->guidFromUrl($episode->video_url);

            $episode->video_status = 'ready';
            $episode->video_url = $this->playlistUrl($guid);
            if (($length = (int) ($video['length'] ?? 0)) > 0) {
                $episode->duration_seconds = $length;
            }
            $thumb = $video['thumbnailFileName'] ?? null;
            if (filled($thumb) && $this->hasNoThumbnail($episode)) {
                $episode->thumbnail_url = 'https://'.$this->cdnHostname().'/'.$guid.'/'.ltrim((string) $thumb, '/');
            }
            $status = $this->persist($episode);

            // The previous Bunny video is only removed once its replacement is playable.
            if ($replaced && strcasecmp($replaced, $guid) !== 0) {
                $this->deleteVideo($replaced);
            }

            return $status;
        }

        if (in_array($status, [self::STATUS_ERROR, self::STATUS_UPLOAD_FAILED], true)) {
            $episode->video_status = 'failed';
        } elseif ($status >= self::STATUS_UPLOADED && in_array($episode->video_status, ['uploading', 'failed', 'none'], true)) {
            $episode->video_status = 'processing';
        }

        return $this->persist($episode);
    }

    // ---- Application sample videos ----------------------------------------

    /** Same as syncEpisode, for a "Request to post" sample video. null = Bunny unreachable (unchanged). */
    public function syncSample(ApplicationSample $sample): ?string
    {
        $guid = $sample->bunny_video_id;
        if (! $guid || ! $this->enabled()) {
            return null;
        }
        try {
            $video = $this->getVideo($guid);
        } catch (Throwable $e) {
            Log::warning('Bunny get video failed', ['video_id' => $guid, 'error' => $e->getMessage()]);

            return null;
        }

        return $this->applySampleVideo($sample, $video);
    }

    /** @param  array|null  $video  Get Video response, or null if Bunny returned 404 */
    public function applySampleVideo(ApplicationSample $sample, ?array $video): string
    {
        if ($video === null) {
            $sample->status = 'failed';
        } elseif (strcasecmp((string) ($video['guid'] ?? ''), (string) $sample->bunny_video_id) === 0) {
            $status = (int) ($video['status'] ?? -1);
            $length = (int) ($video['length'] ?? 0);
            if ($length > 0) {
                $sample->duration_seconds = $length;
            }
            $hasResolution = filled($video['availableResolutions'] ?? null);
            if ($status === self::STATUS_FINISHED
                || ($hasResolution && in_array($status, [self::STATUS_PROCESSING, self::STATUS_TRANSCODING, self::STATUS_JIT_SEGMENTING, self::STATUS_JIT_PLAYLISTS_CREATED], true))) {
                $sample->status = 'ready';
            } elseif (in_array($status, [self::STATUS_ERROR, self::STATUS_UPLOAD_FAILED], true)) {
                $sample->status = 'failed';
            } elseif ($status >= self::STATUS_UPLOADED && $sample->status === 'uploading') {
                $sample->status = 'processing';
            }
        }
        if ($sample->isDirty()) {
            $sample->save();
        }

        return (string) $sample->status;
    }

    protected function hasNoThumbnail(Episode $episode): bool
    {
        $current = $episode->thumbnail_url;
        if (blank($current)) {
            return true;
        }
        // saveEpisode() falls back to the drama poster; that is not a real episode thumbnail.
        $poster = $episode->drama?->poster_url;

        return $poster && $current === $poster;
    }

    protected function persist(Episode $episode): string
    {
        if ($episode->isDirty()) {
            $episode->save();
            CatalogCache::flush();
        }

        return (string) $episode->video_status;
    }
}
