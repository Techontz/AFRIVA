<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Str;

class Payment extends Model
{
    protected $fillable = [
        'user_id', 'plan_id', 'payment_method_code', 'reference', 'amount', 'currency', 'phone', 'status',
        'provider_reference', 'meta', 'paid_at',
        'idempotency_key', 'fee_amount', 'refunded_amount', 'refunded_at', 'receipt_number',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'integer',
            'meta' => 'array',
            'paid_at' => 'datetime',
            'fee_amount' => 'integer',
            'refunded_amount' => 'integer',
            'refunded_at' => 'datetime',
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

    public function method(): BelongsTo
    {
        return $this->belongsTo(PaymentMethod::class, 'payment_method_code', 'code');
    }

    public function subscription(): HasOne
    {
        return $this->hasOne(Subscription::class);
    }

    public function refunds(): HasMany
    {
        return $this->hasMany(Refund::class);
    }

    /** Amount kept after refunds and provider fees. */
    public function netAmount(): int
    {
        return max(0, (int) $this->amount - (int) $this->refunded_amount - (int) $this->fee_amount);
    }

    public static function newReference(): string
    {
        do {
            $ref = 'AFV-'.now()->format('ymd').'-'.Str::upper(Str::random(8));
        } while (static::where('reference', $ref)->exists());

        return $ref;
    }
}
