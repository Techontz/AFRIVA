<?php

namespace App\Support;

use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Support\Facades\Storage;

/**
 * Which disks hold public media (posters, backdrops, thumbnails, logos, avatars) and private documents
 * (creator ID documents). Both are chosen by env so the shared host keeps its local disks unchanged.
 */
class MediaStorage
{
    public static function mediaDiskName(): string
    {
        return (string) (config('filesystems.media_disk') ?: 'public');
    }

    public static function privateDiskName(): string
    {
        return (string) (config('filesystems.private_documents_disk') ?: 'local');
    }

    public static function media(): Filesystem
    {
        return Storage::disk(self::mediaDiskName());
    }

    public static function private(): Filesystem
    {
        return Storage::disk(self::privateDiskName());
    }

    /** True for disks on this server's filesystem (local driver). Cloud disks (s3/R2) return false. */
    public static function isLocal(string $disk): bool
    {
        return config("filesystems.disks.$disk.driver") === 'local';
    }

    /**
     * Writes a public file and returns its public URL. Local disks get an explicit public visibility as before;
     * R2 has no object ACLs, so no visibility is sent there (the bucket's public domain serves it).
     */
    public static function putPublic(string $path, string $contents, ?string $contentType = null): string
    {
        $disk = self::mediaDiskName();
        $options = self::isLocal($disk) ? ['visibility' => 'public'] : [];
        if ($contentType) {
            $options['ContentType'] = $contentType;
        }
        Storage::disk($disk)->put($path, $contents, $options);

        return Storage::disk($disk)->url($path);
    }

    public static function privateUrlTtlMinutes(): int
    {
        return max(1, (int) config('filesystems.private_url_ttl_minutes', 10));
    }
}
