<?php

namespace App\Models;

use App\Support\Permissions;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    public const ROLE_VIEWER = 'viewer';

    public const ROLE_COMPANY = 'company';

    public const ROLE_SUPER_ADMIN = 'super_admin';

    protected $fillable = [
        'name', 'email', 'phone', 'password', 'role', 'staff_role', 'company_id', 'coins', 'avatar_url', 'status',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'coins' => 'integer',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    public function unlocks(): HasMany
    {
        return $this->hasMany(EpisodeUnlock::class);
    }

    public function watchHistories(): HasMany
    {
        return $this->hasMany(WatchHistory::class);
    }

    public function favorites(): BelongsToMany
    {
        return $this->belongsToMany(Drama::class, 'favorites')->withTimestamps();
    }

    public function isSuperAdmin(): bool
    {
        return $this->role === self::ROLE_SUPER_ADMIN;
    }

    /** Staff role for admins (owner|editor|reviewer|finance); admins created before roles existed are owners. */
    public function staffRole(): ?string
    {
        return $this->isSuperAdmin() ? ($this->staff_role ?: 'owner') : null;
    }

    public function hasPermission(string $permission): bool
    {
        return Permissions::allows($this->staffRole(), $permission);
    }

    /** @return list<string> */
    public function permissions(): array
    {
        return Permissions::for($this->staffRole());
    }

    public function coinTransactions(): HasMany
    {
        return $this->hasMany(CoinTransaction::class);
    }

    public function isCompany(): bool
    {
        return $this->role === self::ROLE_COMPANY;
    }

    /** Active weekly/monthly/yearly subscription, if any. */
    public function activeTimeSubscription(): ?Subscription
    {
        return $this->subscriptions()
            ->with('plan')
            ->timeBased()
            ->current()
            ->orderByDesc('ends_at')
            ->first();
    }

    /** Active episode pack with remaining quota (oldest first so it gets used up first). */
    public function activeEpisodePack(): ?Subscription
    {
        return $this->subscriptions()
            ->with('plan')
            ->where('type', 'episodes')
            ->where('status', 'active')
            ->where('episodes_remaining', '>', 0)
            ->orderBy('id')
            ->first();
    }

    public function activeSubscription(): ?Subscription
    {
        return $this->activeTimeSubscription() ?? $this->activeEpisodePack();
    }
}
