<?php

namespace App\Http\Resources;

use App\Support\VideoUrl;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Episode JSON for admin/studio management (always includes video, review and processing state). @mixin \App\Models\Episode */
class StudioEpisodeResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'drama_id' => $this->drama_id,
            'number' => (int) $this->number,
            'title' => $this->title,
            'duration_seconds' => (int) $this->duration_seconds,
            'thumbnail_url' => $this->thumbnail_url,
            'video_url' => VideoUrl::forPlayback($this->video_url),
            'sources' => $this->video_url ? VideoUrl::sources($this->resource) : [],
            'subtitle_url' => $this->subtitle_url,
            'video_status' => $this->video_status,
            'video_error' => $this->video_error,
            'renditions' => $this->renditions ?? [],
            'source_size' => $this->source_size,
            'is_free' => $this->isFree(),
            'is_free_override' => $this->getAttributes()['is_free'] ?? null,
            'review_status' => $this->review_status,
            'review_notes' => $this->review_notes,
            'playback_verified_at' => $this->playback_verified_at?->toIso8601String(),
            'views' => (int) $this->views,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
