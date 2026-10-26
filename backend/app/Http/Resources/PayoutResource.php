<?php

namespace App\Http\Resources;

use App\Models\Payout;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Payout */
class PayoutResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'company_id' => $this->company_id,
            'company' => $this->whenLoaded('company', fn () => $this->company ? [
                'id' => $this->company->id, 'name' => $this->company->name, 'slug' => $this->company->slug,
            ] : null),
            'amount' => (int) $this->amount,
            'status' => $this->status,
            'reference' => $this->reference,
            'paid_at' => $this->paid_at?->toIso8601String(),
            'notes' => $this->notes,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
