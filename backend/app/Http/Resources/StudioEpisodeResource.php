<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Episode JSON for admin/studio management (always includes video_url and override flag). @mixin \App\Models\Episode */
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
            'video_url' => $this->video_url,
            'is_free' => $this->isFree(),
            'is_free_override' => $this->getAttributes()['is_free'] ?? null,
            'views' => (int) $this->views,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
