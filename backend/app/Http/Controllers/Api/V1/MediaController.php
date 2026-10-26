<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Support\VideoUrl;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;

/** GET /media/videos/{path}: serves a private video file or HLS playlist behind a signed, expiring URL. */
class MediaController extends Controller
{
    public function video(string $path): Response
    {
        $disk = Storage::disk('videos');
        if (str_contains($path, '..') || ! $disk->exists($path)) {
            throw new ApiException('Hakipatikani.', 'not_found', 404);
        }

        if (str_ends_with($path, '.m3u8')) {
            return response($this->signPlaylist($disk->get($path), dirname($path)), 200, [
                'Content-Type' => 'application/vnd.apple.mpegurl',
                'Cache-Control' => 'private, no-store',
            ]);
        }

        $headers = [
            'Content-Type' => $disk->mimeType($path) ?: 'video/mp4',
            'Cache-Control' => 'private, max-age='.(config('media.video_url_ttl') * 60),
        ];

        if (config('media.video_delivery') === 'x-accel') {
            // Nginx serves the bytes (with Range support) from its internal location.
            return response('', 200, $headers + ['X-Accel-Redirect' => config('media.x_accel_prefix').$path]);
        }

        return response()->file($disk->path($path), $headers);
    }

    /** Playlists reference segments / variant playlists by relative path; each becomes its own signed URL. */
    protected function signPlaylist(string $playlist, string $dir): string
    {
        $lines = preg_split('/\r\n|\n|\r/', $playlist);

        return implode("\n", array_map(function (string $line) use ($dir) {
            $trimmed = trim($line);
            if ($trimmed === '' || str_starts_with($trimmed, '#') || str_contains($trimmed, '://') || str_contains($trimmed, '..')) {
                return $line;
            }

            return VideoUrl::signed(ltrim($dir.'/'.$trimmed, '/'));
        }, $lines));
    }
}
