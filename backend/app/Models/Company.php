<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Company extends Model
{
    protected $fillable = [
        'name', 'slug', 'logo_url', 'email', 'phone', 'country', 'revenue_share_percent', 'status', 'description',
        'agreement_accepted_at', 'agreement_version',
    ];

    protected function casts(): array
    {
        return ['revenue_share_percent' => 'float', 'agreement_accepted_at' => 'datetime'];
    }

    public function dramas(): HasMany
    {
        return $this->hasMany(Drama::class);
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function earnings(): HasMany
    {
        return $this->hasMany(CompanyEarning::class);
    }

    public function payouts(): HasMany
    {
        return $this->hasMany(Payout::class);
    }

    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    public function hasAcceptedAgreement(): bool
    {
        return $this->agreement_accepted_at !== null && $this->agreement_version === Setting::get('creator_agreement_version');
    }

    public function shareFraction(): float
    {
        return ((float) $this->revenue_share_percent) / 100;
    }
}
