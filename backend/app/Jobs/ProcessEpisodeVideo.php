<?php

namespace App\Jobs;

use App\Models\Episode;
use App\Services\VideoProcessor;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Throwable;

/** Transcode an uploaded episode video to HLS 480p/720p/1080p and grab a thumbnail. */
class ProcessEpisodeVideo implements ShouldQueue
{
    use Queueable;

    public int $tries = 1;

    public int $timeout;

    public function __construct(public int $episodeId)
    {
        $this->timeout = (int) config('media.transcode_timeout') + 60;
    }

    public function handle(VideoProcessor $processor): void
    {
        $episode = Episode::find($this->episodeId);
        if ($episode) {
            $processor->process($episode);
        }
    }

    public function failed(?Throwable $e): void
    {
        Episode::whereKey($this->episodeId)->update([
            'video_status' => 'failed',
            'video_error' => mb_substr($e?->getMessage() ?? 'Transcoding failed.', 0, 1000),
        ]);
    }
}
