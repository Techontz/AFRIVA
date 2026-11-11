<?php

namespace App\Support;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Converts uploaded public images to WebP with GD (downscaled to fit the given box, aspect ratio kept).
 * Returns null when GD has no WebP support or the image cannot be decoded, so callers store the original.
 */
class WebpImage
{
    public const QUALITY = 78;

    protected static bool $warned = false;

    public static function supported(): bool
    {
        return function_exists('imagewebp') && function_exists('imagecreatefromstring')
            && (bool) (gd_info()['WebP Support'] ?? false);
    }

    public static function isImage(UploadedFile $file): bool
    {
        return in_array(strtolower((string) $file->getMimeType()), ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp', 'image/x-ms-bmp'], true);
    }

    /** WebP bytes, or null to keep the original. */
    public static function encode(UploadedFile $file, int $maxWidth, int $maxHeight): ?string
    {
        if (! static::supported()) {
            if (! static::$warned) {
                static::$warned = true;
                Log::warning('GD has no WebP support: images are stored unconverted.');
            }

            return null;
        }
        try {
            $raw = file_get_contents($file->getRealPath());
            $image = $raw !== false ? @imagecreatefromstring($raw) : false;
            if (! $image) {
                return null;
            }
            $image = static::orient($image, $file);

            $w = imagesx($image);
            $h = imagesy($image);
            $scale = min(1, $maxWidth / $w, $maxHeight / $h);
            if ($scale < 1) {
                $nw = max(1, (int) round($w * $scale));
                $nh = max(1, (int) round($h * $scale));
                $resized = imagecreatetruecolor($nw, $nh);
                imagealphablending($resized, false);
                imagesavealpha($resized, true);
                imagefill($resized, 0, 0, imagecolorallocatealpha($resized, 0, 0, 0, 127));
                imagecopyresampled($resized, $image, 0, 0, 0, 0, $nw, $nh, $w, $h);
                imagedestroy($image);
                $image = $resized;
            } elseif (! imageistruecolor($image)) {
                imagepalettetotruecolor($image);
            }
            imagealphablending($image, false);
            imagesavealpha($image, true);

            ob_start();
            $ok = imagewebp($image, null, self::QUALITY);
            $bytes = ob_get_clean();
            imagedestroy($image);

            return $ok && $bytes ? $bytes : null;
        } catch (Throwable $e) {
            Log::warning('WebP conversion failed, storing original', ['error' => $e->getMessage()]);

            return null;
        }
    }

    /** Applies the EXIF orientation of phone photos (JPEG only, when the exif extension exists). */
    protected static function orient(\GdImage $image, UploadedFile $file): \GdImage
    {
        if (! function_exists('exif_read_data') || strtolower((string) $file->getMimeType()) !== 'image/jpeg') {
            return $image;
        }
        $orientation = (int) (@exif_read_data($file->getRealPath())['Orientation'] ?? 1);
        $angle = [3 => 180, 6 => -90, 8 => 90][$orientation] ?? 0;
        if ($angle === 0) {
            return $image;
        }
        $rotated = imagerotate($image, $angle, 0);

        return $rotated ?: $image;
    }
}
