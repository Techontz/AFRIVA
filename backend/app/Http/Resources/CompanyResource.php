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
            // Admin and studio screens only (this resource is never used by public endpoints).
            'payout' => $this->payoutAccount(),
            'dramas_count' => $this->when(isset($this->dramas_count), fn () => (int) $this->dramas_count),
            'total_views' => $this->when(isset($this->total_views), fn () => (int) $this->total_views),
            'total_earnings' => $this->when(isset($this->total_earnings), fn () => (int) $this->total_earnings),
            'owner' => $this->whenLoaded('users', function () {
                $owner = $this->users->firstWhere('role', 'company');

                return $owner ? ['id' => $owner->id, 'name' => $owner->name, 'email' => $owner->email, 'phone' => $owner->phone] : null;
            }),
            'application' => $this->when(
                $this->relationLoaded('application') && $request->user()?->role === 'super_admin',
                fn () => $this->application ? [
                    'id' => $this->application->id,
                    'status' => $this->application->status,
                    'review_status' => $this->application->relationLoaded('samples') ? $this->application->reviewStatus() : $this->application->status,
                    'rejection_reason' => $this->application->rejection_reason,
                    'samples_summary' => $this->application->relationLoaded('samples') ? $this->application->samplesSummary() : null,
                    'full_name' => $this->application->full_name,
                    'id_type' => $this->application->id_type,
                    'id_number' => $this->application->id_number,
                    'has_id_document' => $this->application->id_document_path !== null,
                    'phone' => $this->application->phone,
                    'email' => $this->application->user?->email ?? $this->email,
                    'existing_user' => $this->application->existing_user,
                    'guidelines_accepted_at' => $this->application->guidelines_accepted_at?->toIso8601String(),
                    'creator_share_percent' => $this->application->creator_share_percent,
                    'reviewed_at' => $this->application->reviewed_at?->toIso8601String(),
                    'created_at' => $this->application->created_at?->toIso8601String(),
                ] : null
            ),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
