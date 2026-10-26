<?php

namespace App\Support;

use App\Models\Episode;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\URL;

/**
 * Episode video locations. Uploaded files are stored on the private "videos" disk and
 * saved in episodes.video_url as "private:<path>"; anything else (external URLs) is
 * passed through unchanged. Transcoded episodes also have an HLS ladder under hls/<episode id>/.
 * See config/media.php.
 */
class VideoUrl
{
    public const PREFIX = 'private:';

    public static function store(UploadedFile $file, string $dir = 'episodes'): string
    {
        return self::PREFIX.$file->store($dir, 'videos');
    }

    public static function isPrivate(?string $stored): bool
    {
        return $stored !== null && str_starts_with($stored, self::PREFIX);
    }

    public static function path(string $stored): string
    {
        return substr($stored, strlen(self::PREFIX));
    }

    /** URL a player can load: a temporary signed media URL for private files, else the stored URL. */
    public static function forPlayback(?string $stored): ?string
    {
        if (! self::isPrivate($stored)) {
            return $stored;
        }

        return self::signed(self::path($stored));
    }

    /** Absolute signed URL for a path on the videos disk. */
    public static function signed(string $path): string
    {
        $relative = URL::temporarySignedRoute(
            'media.video',
            now()->addMinutes(config('media.video_url_ttl')),
            ['path' => $path],
            absolute: false,
        );

        return rtrim(config('app.url'), '/').$relative;
    }

    /**
     * Playable sources for the quality picker: "auto" first (adaptive HLS when transcoded), then fixed renditions.
     *
     * @return list<array{quality:string,label:string,url:string|null,type:string}>
     */
    public static function sources(Episode $episode): array
    {
        if ($episode->hls_path && $episode->video_status === 'ready') {
            $dir = dirname($episode->hls_path);
            $sources = [['quality' => 'auto', 'label' => 'Auto', 'url' => self::signed($episode->hls_path), 'type' => 'hls']];
            foreach (array_reverse($episode->renditions ?? []) as $rendition) {
                $sources[] = ['quality' => $rendition, 'label' => $rendition, 'url' => self::signed("{$dir}/{$rendition}/index.m3u8"), 'type' => 'hls'];
            }

            return $sources;
        }

        $url = self::forPlayback($episode->video_url);
        $type = str_contains(strtolower((string) parse_url((string) $episode->video_url, PHP_URL_PATH)), '.m3u8') ? 'hls' : 'mp4';

        return [['quality' => 'auto', 'label' => 'Auto', 'url' => $url, 'type' => $type]];
    }

    /** Main URL for the player: the HLS master when transcoded, else the original file. */
    public static function primary(Episode $episode): ?string
    {
        return self::sources($episode)[0]['url'];
    }

    /**
     * Value to save when a client submits video_url. Studio/admin forms send back the signed URL
     * they were given, so map our own media URLs back to the stored path, and never accept a
     * raw "private:" path that differs from what the episode already has.
     */
    public static function fromInput(?string $incoming, ?string $current): ?string
    {
        if ($incoming === null || $incoming === '') {
            return $incoming;
        }
        if (self::isPrivate($incoming)) {
            return $incoming === $current ? $incoming : $current;
        }

        $path = parse_url($incoming, PHP_URL_PATH) ?: '';
        $marker = '/api/v1/media/videos/';
        if (str_contains($path, $marker)) {
            $mapped = self::PREFIX.rawurldecode(substr($path, strpos($path, $marker) + strlen($marker)));

            // A signed HLS URL handed back by a form still means "keep the current source file".
            return str_starts_with($mapped, self::PREFIX.'hls/') ? $current : $mapped;
        }

        return $incoming;
    }
}
