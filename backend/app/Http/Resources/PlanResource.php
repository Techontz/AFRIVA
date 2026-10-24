<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Plan */
class PlanResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'type' => $this->type,
            'price' => (int) $this->price,
            'currency' => $this->currency,
            'duration_days' => $this->duration_days,
            'episode_quota' => $this->episode_quota,
            'coins' => $this->coins,
            'bonus_coins' => $this->bonus_coins,
            'description' => $this->description,
            'features' => $this->features ?? [],
            'is_popular' => (bool) $this->is_popular,
            'is_active' => (bool) $this->is_active,
            'sort_order' => (int) $this->sort_order,
        ];
    }
}
