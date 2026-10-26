<?php

namespace App\Http\Resources;

use App\Models\Company;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Company */
class CompanyResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'logo_url' => $this->logo_url,
            'email' => $this->email,
            'phone' => $this->phone,
            'country' => $this->country,
            'revenue_share_percent' => (float) $this->revenue_share_percent,
            'status' => $this->status,
            'description' => $this->description,
            'agreement_accepted_at' => $this->agreement_accepted_at?->toIso8601String(),
            'agreement_version' => $this->agreement_version,
            'dramas_count' => $this->when(isset($this->dramas_count), fn () => (int) $this->dramas_count),
            'total_views' => $this->when(isset($this->total_views), fn () => (int) $this->total_views),
            'total_earnings' => $this->when(isset($this->total_earnings), fn () => (int) $this->total_earnings),
            'owner' => $this->whenLoaded('users', function () {
                $owner = $this->users->firstWhere('role', 'company');

                return $owner ? ['id' => $owner->id, 'name' => $owner->name, 'email' => $owner->email, 'phone' => $owner->phone] : null;
            }),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
