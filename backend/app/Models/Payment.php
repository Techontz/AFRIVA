<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Str;

class Payment extends Model
{
    protected $fillable = [
        'user_id', 'plan_id', 'payment_method_code', 'reference', 'amount', 'currency', 'phone', 'status',
        'provider_reference', 'meta', 'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'integer',
            'meta' => 'array',
            'paid_at' => 'datetime',
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

    public static function newReference(): string
    {
        do {
            $ref = 'AFV-'.now()->format('ymd').'-'.Str::upper(Str::random(8));
        } while (static::where('reference', $ref)->exists());

        return $ref;
    }
}
