<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payout extends Model
{
    protected $fillable = ['company_id', 'amount', 'status', 'reference', 'paid_at', 'notes'];

    protected function casts(): array
    {
        return ['amount' => 'integer', 'paid_at' => 'datetime'];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }
}
