<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SavedPaymentMethod extends Model
{
    protected $fillable = [
        'user_id', 'type', 'method_code', 'phone', 'card_last4', 'card_exp_month', 'card_exp_year',
        'provider_token', 'is_default', 'last_used_at',
    ];

    protected $hidden = ['provider_token'];

    protected function casts(): array
    {
        return [
            'provider_token' => 'encrypted',
            'is_default' => 'boolean',
            'card_exp_month' => 'integer',
            'card_exp_year' => 'integer',
            'last_used_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function method(): BelongsTo
    {
        return $this->belongsTo(PaymentMethod::class, 'method_code', 'code');
    }

    public function isExpired(): bool
    {
        if ($this->type !== 'card' || ! $this->card_exp_year || ! $this->card_exp_month) {
            return false;
        }

        return now()->startOfMonth()->gt(now()->setDate($this->card_exp_year, $this->card_exp_month, 1)->startOfMonth());
    }

    /**
     * Save (or refresh) a way to pay for a user and make it their default. Matching numbers and cards are
     * updated rather than duplicated.
     *
     * @param  array<string,mixed>  $attrs
     */
    public static function remember(User $user, array $attrs): self
    {
        $match = static::where('user_id', $user->id)->where('type', $attrs['type']);
        if ($attrs['type'] === 'mobile_money') {
            $match->where('phone', $attrs['phone']);
        } else {
            $match->where('method_code', $attrs['method_code'])->where('card_last4', $attrs['card_last4'])
                ->where('card_exp_month', $attrs['card_exp_month'] ?? null)->where('card_exp_year', $attrs['card_exp_year'] ?? null);
        }

        $saved = $match->first() ?? new static(['user_id' => $user->id]);
        $saved->fill(array_filter($attrs, fn ($v) => $v !== null));
        $saved->last_used_at = now();
        $saved->save();
        $saved->makeDefault();

        return $saved;
    }

    public function makeDefault(): void
    {
        static::where('user_id', $this->user_id)->whereKeyNot($this->id)->update(['is_default' => false]);
        if (! $this->is_default) {
            $this->forceFill(['is_default' => true])->save();
        }
    }
}
