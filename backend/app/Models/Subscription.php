<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Subscription extends Model
{
    protected $fillable = [
        'user_id', 'plan_id', 'payment_id', 'type', 'starts_at', 'ends_at', 'episodes_remaining', 'status',
    ];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'episodes_remaining' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(Plan::class);
    }

    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class);
    }

    public function scopeTimeBased(Builder $q): Builder
    {
        return $q->whereIn('type', Plan::TIME_TYPES);
    }

    /** Active and within its time window. */
    public function scopeCurrent(Builder $q): Builder
    {
        $now = now();

        return $q->where('status', 'active')
            ->where(fn ($w) => $w->whereNull('starts_at')->orWhere('starts_at', '<=', $now))
            ->where(fn ($w) => $w->whereNull('ends_at')->orWhere('ends_at', '>', $now));
    }

    public function isActive(): bool
    {
        if ($this->status !== 'active') {
            return false;
        }
        if ($this->type === 'episodes') {
            return (int) $this->episodes_remaining > 0;
        }

        return (! $this->starts_at || $this->starts_at->lte(now())) && (! $this->ends_at || $this->ends_at->gt(now()));
    }
}
