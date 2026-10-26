<?php

namespace App\Http\Resources;

use App\Models\Episode;
use App\Services\EpisodeAccessService;
use App\Support\VideoUrl;
use App\Support\Viewer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Episode JSON. video_url is only included when explicitly requested (play endpoint / feed / studio).
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
        $isFree = $this->isFree();
        $unlocked = $isFree || $access->canWatch(Viewer::user(), $this->resource);
        $drama = $this->drama;

        return [
            'id' => $this->id,
            'drama_id' => $this->drama_id,
            'number' => (int) $this->number,
            'title' => $this->title,
            'duration_seconds' => (int) $this->duration_seconds,
            'thumbnail_url' => $this->thumbnail_url,
            'is_free' => $isFree,
            'is_unlocked' => $unlocked,
            // free | unlocked | locked: lets clients label every episode before it is tapped (scope §02).
            'access' => $isFree ? 'free' : ($unlocked ? 'unlocked' : 'locked'),
            'price_coins' => $isFree || $drama?->access_mode === 'vip_only' ? 0 : (int) $drama?->coins_per_episode,
            'vip_only' => ! $isFree && $drama?->access_mode === 'vip_only',
            'subtitle_url' => $this->subtitle_url,
            'views' => (int) $this->views,
            'video_url' => $this->when($this->withVideo, fn () => VideoUrl::primary($this->resource)),
            'sources' => $this->when($this->withVideo, fn () => VideoUrl::sources($this->resource)),
        ];
    }
}
