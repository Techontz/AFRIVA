<?php

namespace App\Http\Resources;

use App\Models\Subscription;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Subscription */
class SubscriptionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'status' => $this->status,
            'is_active' => $this->isActive(),
            'starts_at' => $this->starts_at?->toIso8601String(),
            'ends_at' => $this->ends_at?->toIso8601String(),
            'episodes_remaining' => $this->episodes_remaining,
            'plan' => $this->whenLoaded('plan', fn () => $this->plan ? new PlanResource($this->plan) : null),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
