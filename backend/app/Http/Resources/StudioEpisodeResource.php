<?php

namespace App\Http\Resources;

use App\Models\Episode;
use App\Services\BunnyStream;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Episode JSON for admin/studio management (always includes video_url and override flag).
 * video_url / thumbnail_url are the raw stored values (safe to send back on update); playback_url and
 * thumbnail_preview_url are signed for previewing when Bunny token authentication is on.
 *
 * @mixin Episode
 */
class StudioEpisodeResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $bunny = app(BunnyStream::class);

        return [
            'id' => $this->id,
            'drama_id' => $this->drama_id,
            'number' => (int) $this->number,
            'title' => $this->title,
            'duration_seconds' => (int) $this->duration_seconds,
            'orientation' => $this->orientation ?? 'portrait',
            'thumbnail_url' => $this->thumbnail_url,
            'thumbnail_preview_url' => $bunny->signAssetUrl($this->thumbnail_url),
            'video_url' => $this->video_url,
            'playback_url' => $bunny->playbackUrl($this->resource),
            'video_status' => $this->video_status ?? 'none',
            'bunny_video_id' => $this->bunny_video_id,
            'is_free' => $this->isFree(),
            'is_free_override' => $this->getAttributes()['is_free'] ?? null,
            'views' => (int) $this->views,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
