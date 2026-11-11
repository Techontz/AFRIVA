<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Company extends Model
{
    protected $fillable = [
        'name', 'slug', 'logo_url', 'email', 'phone', 'country', 'revenue_share_percent', 'status', 'description',
        'payout_method', 'payout_provider', 'payout_bank_name', 'payout_account_name', 'payout_account_number',
    ];

    public const PAYOUT_METHODS = ['mobile_money', 'bank'];

    /** Tanzanian mobile money wallets accepted for payouts. */
    public const PAYOUT_PROVIDERS = ['mpesa', 'mixx', 'airtel', 'halopesa', 'tpesa'];

    protected static function booted(): void
    {
        // Studios without an explicit percentage follow the admin setting (Admin > Settings).
        static::creating(function (Company $company) {
            if ($company->revenue_share_percent === null) {
                $company->revenue_share_percent = Setting::creatorShare();
            }
        });
    }

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

    /** The latest "Request to post" submission for this studio, if it signed up itself. */
    public function application(): HasOne
    {
        return $this->hasOne(StudioApplication::class)->latestOfMany();
    }

    /** @return array<string,string|null> */
    public function payoutAccount(): array
    {
        return [
            'method' => $this->payout_method,
            'provider' => $this->payout_provider,
            'bank_name' => $this->payout_bank_name,
            'account_name' => $this->payout_account_name,
            'account_number' => $this->payout_account_number,
        ];
    }

    public function shareFraction(): float
    {
        return ((float) $this->revenue_share_percent) / 100;
    }
}
