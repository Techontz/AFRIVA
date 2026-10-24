<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\User */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $active = $this->activeSubscription();

        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'role' => $this->role,
            'coins' => (int) $this->coins,
            'avatar_url' => $this->avatar_url,
            'status' => $this->status,
            'company_id' => $this->company_id,
            'company' => $this->company ? [
                'id' => $this->company->id, 'name' => $this->company->name, 'slug' => $this->company->slug,
                'logo_url' => $this->company->logo_url,
            ] : null,
            'is_vip' => $active !== null && $active->type !== 'episodes',
            'active_subscription' => $active ? new SubscriptionResource($active) : null,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
