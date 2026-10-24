<?php

namespace App\Http\Resources;

use App\Services\EpisodeAccessService;
use App\Support\Viewer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Episode JSON. video_url is only included when explicitly requested (play endpoint / feed / studio).
 *
 * @mixin \App\Models\Episode
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

        return [
            'id' => $this->id,
            'drama_id' => $this->drama_id,
            'number' => (int) $this->number,
            'title' => $this->title,
            'duration_seconds' => (int) $this->duration_seconds,
            'thumbnail_url' => $this->thumbnail_url,
            'is_free' => $isFree,
            'is_unlocked' => $isFree || $access->canWatch(Viewer::user(), $this->resource),
            'views' => (int) $this->views,
            'video_url' => $this->when($this->withVideo, fn () => $this->video_url),
        ];
    }
}
