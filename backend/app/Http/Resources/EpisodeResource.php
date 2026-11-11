<?php

namespace App\Http\Resources;

use App\Models\Episode;
use App\Services\BunnyStream;
use App\Services\EpisodeAccessService;
use App\Support\Viewer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Episode JSON. video_url is only included when explicitly requested (play endpoint / feed / studio), and the
 * caller must have checked access first. It is null while the episode has no playable video ("coming soon").
 * The playback URL is signed per request and must never be stored in CatalogCache (only withVideo() output
 * carries it). thumbnail_url uses a bucketed long lived token, which is stable and safe to cache.
 *
 * @mixin Episode
 */
class EpisodeResource extends JsonResource
{
    protected bool $withVideo = false;

    public function withVideo(bool $flag = true): static
    {
        $this->withVideo = $flag;

        return $this;
    }

    public function toArray(Request $request): array
    {
        $access = app(EpisodeAccessService::class);
        $bunny = app(BunnyStream::class);
        $isFree = $this->isFree();

        return [
            'id' => $this->id,
            'drama_id' => $this->drama_id,
            'number' => (int) $this->number,
            'title' => $this->title,
            'duration_seconds' => (int) $this->duration_seconds,
            'orientation' => $this->orientation ?? 'portrait',
            'thumbnail_url' => $bunny->signAssetUrl($this->thumbnail_url),
            'is_free' => $isFree,
            'is_unlocked' => $isFree || $access->canWatch(Viewer::user(), $this->resource),
            'views' => (int) $this->views,
            'video_url' => $this->when($this->withVideo, fn () => $bunny->playbackUrl($this->resource)),
        ];
    }
}
