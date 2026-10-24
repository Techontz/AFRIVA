<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\CompanyEarning */
class CompanyEarningResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'company_id' => $this->company_id,
            'drama_id' => $this->drama_id,
            'drama' => $this->whenLoaded('drama', fn () => $this->drama ? [
                'id' => $this->drama->id, 'title' => $this->drama->title, 'slug' => $this->drama->slug,
            ] : null),
            'source' => $this->source,
            'amount' => (int) $this->amount,
            'period_date' => substr((string) $this->period_date, 0, 10),
            'meta' => $this->meta ?? (object) [],
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
