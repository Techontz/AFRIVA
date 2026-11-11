<?php

namespace App\Console\Commands;

use App\Models\ApplicationSample;
use App\Models\Episode;
use App\Services\BunnyStream;
use Illuminate\Console\Command;

/** Fallback for missed webhooks: re-checks episodes still uploading/processing against Bunny's Get Video. */
class SyncBunnyVideos extends Command
{
    protected $signature = 'bunny:sync {--min-age=2 : Only episodes untouched for at least this many minutes}';

    protected $description = 'Sync Bunny Stream video status for episodes that are still uploading or processing';

    /** An upload that never received a file after this long is given up on (TUS signatures last 6 hours). */
    protected const ABANDON_AFTER_HOURS = 24;

    public function handle(BunnyStream $bunny): int
    {
        if (! $bunny->enabled()) {
            $this->info('Bunny Stream is not configured; nothing to sync.');

            return self::SUCCESS;
        }

        $checked = 0;
        $changed = 0;
        Episode::with('drama')
            ->whereIn('video_status', ['uploading', 'processing'])
            ->whereNotNull('bunny_video_id')
            ->where('updated_at', '<=', now()->subMinutes(max(0, (int) $this->option('min-age'))))
            ->chunkById(100, function ($episodes) use ($bunny, &$checked, &$changed) {
                foreach ($episodes as $episode) {
                    $checked++;
                    $before = $episode->video_status;
                    $after = $bunny->syncEpisode($episode);

                    if ($after === 'uploading' && $episode->updated_at->lt(now()->subHours(self::ABANDON_AFTER_HOURS))) {
                        $episode->video_status = 'failed';
                        $episode->save();
                        $after = 'failed';
                    }
                    if ($after !== null && $after !== $before) {
                        $changed++;
                    }
                }
            });

        $this->info("Checked {$checked} episode(s), {$changed} changed.");

        // "Request to post" sample videos.
        $samples = 0;
        ApplicationSample::whereIn('status', ['uploading', 'processing'])
            ->whereNotNull('bunny_video_id')
            ->where('updated_at', '<=', now()->subMinutes(max(0, (int) $this->option('min-age'))))
            ->chunkById(100, function ($rows) use ($bunny, &$samples) {
                foreach ($rows as $sample) {
                    $samples++;
                    $after = $bunny->syncSample($sample);
                    if ($after === 'uploading' && $sample->updated_at->lt(now()->subHours(self::ABANDON_AFTER_HOURS))) {
                        $sample->update(['status' => 'failed']);
                    }
                }
            });
        $this->info("Checked {$samples} sample video(s).");

        return self::SUCCESS;
    }
}
