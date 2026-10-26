<?php

namespace App\Services;

use App\Jobs\ProcessEpisodeVideo;
use App\Models\Episode;
use App\Support\VideoUrl;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

/**
 * Video tools (scope §05/§08): probe, transcode to an adaptive HLS ladder, thumbnail.
 * Trimming/cropping is not done here; creators upload the final cut.
 */
class VideoProcessor
{
    /** Called after an episode gets a new video file: queue transcoding, or mark it ready when transcoding is off. */
    public function queue(Episode $episode): void
    {
        if (! VideoUrl::isPrivate($episode->video_url) || ! config('media.transcode')) {
            $episode->forceFill(['video_status' => 'ready', 'video_error' => null, 'hls_path' => null, 'renditions' => null])->save();

            return;
        }

        $episode->forceFill(['video_status' => 'processing', 'video_error' => null, 'hls_path' => null, 'renditions' => null])->save();
        ProcessEpisodeVideo::dispatch($episode->id)->afterCommit();
    }

    public function process(Episode $episode): void
    {
        if (! VideoUrl::isPrivate($episode->video_url)) {
            $episode->forceFill(['video_status' => 'ready', 'video_error' => null])->save();

            return;
        }

        $disk = Storage::disk('videos');
        $source = VideoUrl::path($episode->video_url);
        if (! $disk->exists($source)) {
            throw new RuntimeException("Video file is missing: {$source}");
        }
        $episode->forceFill(['video_status' => 'processing', 'video_error' => null])->save();

        $input = $disk->path($source);
        [$width, $height, $duration] = $this->probe($input);
        $portrait = $height > $width;
        $sourceShort = min($width, $height);

        $outDir = "hls/{$episode->id}";
        $disk->deleteDirectory($outDir);

        $ladder = array_filter(config('media.renditions'), fn ($kbps, $short) => $short <= max($sourceShort, 480), ARRAY_FILTER_USE_BOTH);
        ksort($ladder);

        $master = ['#EXTM3U', '#EXT-X-VERSION:3'];
        $names = [];
        foreach ($ladder as $short => $kbps) {
            $name = "{$short}p";
            $disk->makeDirectory("{$outDir}/{$name}");
            $dir = $disk->path("{$outDir}/{$name}");
            $scale = $portrait ? "{$short}:-2" : "-2:{$short}";

            $this->run([
                config('media.ffmpeg'), '-y', '-i', $input,
                '-vf', "scale={$scale}", '-c:v', 'libx264', '-preset', 'veryfast', '-profile:v', 'main',
                '-b:v', "{$kbps}k", '-maxrate', (int) ($kbps * 1.1).'k', '-bufsize', ($kbps * 2).'k',
                '-g', '48', '-keyint_min', '48', '-sc_threshold', '0',
                '-c:a', 'aac', '-b:a', '128k', '-ac', '2',
                '-hls_time', (string) config('media.hls_segment_seconds'), '-hls_playlist_type', 'vod',
                '-hls_segment_filename', "{$dir}/seg_%04d.ts", "{$dir}/index.m3u8",
            ]);

            [$w, $h] = $portrait
                ? [$short, (int) (round($short * $height / max(1, $width) / 2) * 2)]
                : [(int) (round($short * $width / max(1, $height) / 2) * 2), $short];
            $master[] = '#EXT-X-STREAM-INF:BANDWIDTH='.(($kbps + 128) * 1000).",RESOLUTION={$w}x{$h}";
            $master[] = "{$name}/index.m3u8";
            $names[] = $name;
        }
        $disk->put("{$outDir}/master.m3u8", implode("\n", $master)."\n");

        $updates = [
            'hls_path' => "{$outDir}/master.m3u8",
            'renditions' => $names,
            'video_status' => 'ready',
            'video_error' => null,
            'source_size' => $disk->size($source),
        ];
        if ($duration > 0) {
            $updates['duration_seconds'] = (int) round($duration);
        }
        if (! $episode->thumbnail_url || $episode->thumbnail_url === $episode->drama?->poster_url) {
            $updates['thumbnail_url'] = $this->thumbnail($input, $episode, $duration, $portrait) ?? $episode->thumbnail_url;
        }
        $episode->forceFill($updates)->save();
    }

    /** @return array{0:int,1:int,2:float} width, height, duration seconds */
    protected function probe(string $input): array
    {
        $out = $this->run([
            config('media.ffprobe'), '-v', 'error', '-select_streams', 'v:0',
            '-show_entries', 'stream=width,height:format=duration', '-of', 'json', $input,
        ]);
        $json = json_decode($out, true) ?: [];
        $stream = $json['streams'][0] ?? [];
        if (empty($stream['width']) || empty($stream['height'])) {
            throw new RuntimeException('Faili hili halina video inayosomeka.');
        }

        return [(int) $stream['width'], (int) $stream['height'], (float) ($json['format']['duration'] ?? 0)];
    }

    protected function thumbnail(string $input, Episode $episode, float $duration, bool $portrait): ?string
    {
        $path = "thumbnails/ep-{$episode->id}-".time().'.jpg';
        $public = Storage::disk('public');
        $public->makeDirectory('thumbnails');
        try {
            $this->run([
                config('media.ffmpeg'), '-y', '-ss', (string) min(3, max(0, $duration / 2)), '-i', $input,
                '-frames:v', '1', '-vf', $portrait ? 'scale=360:-2' : 'scale=-2:360', $public->path($path),
            ]);
        } catch (RuntimeException) {
            return null;
        }

        return $public->url($path);
    }

    /** @param list<string> $command */
    protected function run(array $command): string
    {
        $result = Process::timeout((int) config('media.transcode_timeout'))->run($command);
        if (! $result->successful()) {
            throw new RuntimeException(trim(mb_substr($result->errorOutput() ?: $result->output(), -800)) ?: 'ffmpeg failed.');
        }

        return $result->output();
    }
}
