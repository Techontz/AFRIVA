<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Company extends Model
{
    protected $fillable = [
        'name', 'slug', 'logo_url', 'email', 'phone', 'country', 'revenue_share_percent', 'status', 'description',
    ];

    protected function casts(): array
    {
        return ['revenue_share_percent' => 'float'];
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

    public function shareFraction(): float
    {
        return ((float) $this->revenue_share_percent) / 100;
    }
}
