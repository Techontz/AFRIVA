<?php

namespace App\Http\Resources;

use App\Models\ContentReview;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin ContentReview */
class ContentReviewResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'drama_id' => $this->drama_id,
            'episode_id' => $this->episode_id,
            'episode_number' => $this->whenLoaded('episode', fn () => $this->episode?->number),
            'action' => $this->action,
            'from_status' => $this->from_status,
            'to_status' => $this->to_status,
            'notes' => $this->notes,
            'user' => $this->whenLoaded('user', fn () => $this->user ? ['id' => $this->user->id, 'name' => $this->user->name, 'role' => $this->user->role] : null),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
