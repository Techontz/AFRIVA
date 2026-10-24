<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\WatchHistory */
class HistoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'drama' => new DramaResource($this->drama),
            'episode' => $this->episode ? new EpisodeResource($this->episode) : null,
            'progress_seconds' => (int) $this->progress_seconds,
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
