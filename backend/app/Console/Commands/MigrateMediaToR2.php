<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * One-time move of uploaded files to Cloudflare R2.
 *
 * 1. Copies every file on the local public disk to the public bucket (same relative path).
 * 2. Copies every creator ID document from the local private disk to the private bucket (same path, so the
 *    studio_applications.id_document_path values stay valid).
 * 3. Rewrites stored image URLs ({APP_URL}/storage/..., {MEDIA_CDN_URL}/storage/... or /storage/...) to the
 *    public bucket URL, only when the file is present in the bucket.
 *
 * Idempotent: files already in the bucket with the same size are skipped, and URLs already on R2 do not match.
 * Never deletes or changes the local originals. Afterwards set MEDIA_DISK=r2_public and
 * PRIVATE_DOCUMENTS_DISK=r2_private.
 */
class MigrateMediaToR2 extends Command
{
    protected $signature = 'media:migrate-to-r2
        {--dry-run : Report what would be copied and rewritten without changing anything}
        {--from-public=public : Source disk for public media}
        {--from-private=local : Source disk for private documents}
        {--to-public=r2_public : Target disk for public media}
        {--to-private=r2_private : Target disk for private documents}
        {--origin=* : Extra old URL origins to rewrite, e.g. https://old-host.example}';

    protected $description = 'Copy local media and ID documents to R2 and rewrite stored image URLs (never deletes local files)';

    /** Tables and columns that hold absolute image/file URLs. */
    public const URL_COLUMNS = [
        'dramas' => ['poster_url', 'backdrop_url'],
        'episodes' => ['thumbnail_url', 'video_url'],
        'companies' => ['logo_url'],
        'users' => ['avatar_url'],
        'payment_methods' => ['logo_url'],
    ];

    /** Folder on the private disk that holds ID documents (StudioApplicationController). */
    public const PRIVATE_DIRS = ['id-documents'];

    public function handle(): int
    {
        $dry = (bool) $this->option('dry-run');
        $toPublic = (string) $this->option('to-public');
        $toPrivate = (string) $this->option('to-private');

        foreach ([$toPublic, $toPrivate] as $disk) {
            if (! config("filesystems.disks.$disk")) {
                $this->error("Disk [$disk] is not configured.");

                return self::FAILURE;
            }
        }
        if (! $dry && blank(config("filesystems.disks.$toPublic.url"))) {
            $this->error("Disk [$toPublic] has no public URL: set R2_PUBLIC_URL first.");

            return self::FAILURE;
        }

        $this->info($dry ? 'Dry run: nothing will be copied or changed.' : 'Copying media to R2 (local files are kept).');

        $public = $this->copyFiles(Storage::disk((string) $this->option('from-public')), Storage::disk($toPublic), null, $dry);
        $private = $this->copyFiles(Storage::disk((string) $this->option('from-private')), Storage::disk($toPrivate), self::PRIVATE_DIRS, $dry);
        $rows = $this->rewriteUrls(Storage::disk($toPublic), $dry, $public['copyable']);

        $this->newLine();
        $this->table(['Step', 'Copied', 'Already there', 'Failed'], [
            ['Public media', $public['copied'], $public['skipped'], $public['failed']],
            ['Private documents', $private['copied'], $private['skipped'], $private['failed']],
        ]);
        $this->table(['Table.column', 'URLs rewritten', 'Missing file (left as is)'], $rows['table']);
        $this->line(sprintf('%s %d URL(s) in total.', $dry ? 'Would rewrite' : 'Rewrote', $rows['total']));
        if (! $dry) {
            $this->line('Next: set MEDIA_DISK='.$toPublic.' and PRIVATE_DOCUMENTS_DISK='.$toPrivate.', then php artisan config:cache.');
        }

        return ($public['failed'] + $private['failed']) > 0 ? self::FAILURE : self::SUCCESS;
    }

    /**
     * @param  array<int,string>|null  $dirs
     * @return array{copied:int,skipped:int,failed:int,copyable:array<string,bool>}
     */
    protected function copyFiles(Filesystem $from, Filesystem $to, ?array $dirs, bool $dry): array
    {
        $result = ['copied' => 0, 'skipped' => 0, 'failed' => 0, 'copyable' => []];
        $files = $dirs === null
            ? $from->allFiles()
            : collect($dirs)->flatMap(fn (string $d) => $from->allFiles($d))->all();

        foreach ($files as $path) {
            if (str_starts_with(basename($path), '.')) {
                continue; // .gitignore and other dot files
            }
            $result['copyable'][$path] = true;
            try {
                if ($to->exists($path) && $to->size($path) === $from->size($path)) {
                    $result['skipped']++;

                    continue;
                }
                if (! $dry) {
                    $stream = $from->readStream($path);
                    if (! $stream || ! $to->writeStream($path, $stream, array_filter(['ContentType' => $from->mimeType($path) ?: null]))) {
                        throw new \RuntimeException('write failed');
                    }
                    if (is_resource($stream)) {
                        fclose($stream);
                    }
                }
                $result['copied']++;
            } catch (Throwable $e) {
                $result['failed']++;
                $this->warn("  failed: $path ({$e->getMessage()})");
            }
        }

        return $result;
    }

    /**
     * @param  array<string,bool>  $copyable  Paths present on the source disk (will be on R2 after a real run).
     * @return array{table:array<int,array<int,string|int>>,total:int}
     */
    protected function rewriteUrls(Filesystem $target, bool $dry, array $copyable): array
    {
        $prefixes = $this->oldPrefixes();
        $table = [];
        $total = 0;

        foreach (self::URL_COLUMNS as $tableName => $columns) {
            if (! DB::getSchemaBuilder()->hasTable($tableName)) {
                continue;
            }
            foreach ($columns as $column) {
                $rewritten = 0;
                $missing = 0;
                DB::table($tableName)->select(['id', $column])
                    ->where(function ($q) use ($column, $prefixes) {
                        foreach ($prefixes as $prefix) {
                            $q->orWhere($column, 'like', $prefix.'%');
                        }
                    })
                    ->orderBy('id')
                    ->chunkById(500, function ($rows) use ($tableName, $column, $prefixes, $target, $dry, $copyable, &$rewritten, &$missing) {
                        foreach ($rows as $row) {
                            $path = $this->relativePath((string) $row->{$column}, $prefixes);
                            $present = $path !== null && ($dry ? isset($copyable[$path]) : $target->exists($path));
                            if (! $present) {
                                $missing++;

                                continue;
                            }
                            if (! $dry) {
                                DB::table($tableName)->where('id', $row->id)->update([$column => $target->url($path)]);
                            }
                            $rewritten++;
                        }
                    });
                $table[] = ["$tableName.$column", $rewritten, $missing];
                $total += $rewritten;
            }
        }

        return ['table' => $table, 'total' => $total];
    }

    /** @return array<int,string> URL prefixes of files served from the local public disk, longest first. */
    protected function oldPrefixes(): array
    {
        $origins = array_merge(
            [config('app.url'), config('services.bunny.media_cdn_url')],
            (array) $this->option('origin'),
        );
        $prefixes = ['/storage/'];
        foreach ($origins as $origin) {
            $origin = rtrim((string) $origin, '/');
            if ($origin !== '') {
                $prefixes[] = $origin.'/storage/';
            }
        }
        $prefixes = array_values(array_unique($prefixes));
        usort($prefixes, fn ($a, $b) => strlen($b) <=> strlen($a));

        return $prefixes;
    }

    /** @param array<int,string> $prefixes */
    protected function relativePath(string $url, array $prefixes): ?string
    {
        foreach ($prefixes as $prefix) {
            if (str_starts_with($url, $prefix)) {
                $path = ltrim(rawurldecode(strtok(substr($url, strlen($prefix)), '?#') ?: ''), '/');

                return $path === '' || str_contains($path, '..') ? null : $path;
            }
        }

        return null;
    }
}
