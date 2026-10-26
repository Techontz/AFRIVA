<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Coin ledger entry. Every change to users.coins goes through App\Services\CoinLedger. */
class CoinTransaction extends Model
{
    public const TYPES = ['purchase', 'bonus', 'unlock', 'admin_adjust', 'refund'];

    protected $fillable = ['user_id', 'amount', 'balance_after', 'type', 'payment_id', 'episode_id', 'actor_id', 'description'];

    protected function casts(): array
    {
        return ['amount' => 'integer', 'balance_after' => 'integer'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class);
    }

    public function episode(): BelongsTo
    {
        return $this->belongsTo(Episode::class);
    }
}
