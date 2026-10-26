<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CompanyEarning extends Model
{
    // period_date stored as Y-m-d string (no date cast) for DB-agnostic grouping.
    protected $fillable = ['company_id', 'drama_id', 'episode_id', 'source', 'amount', 'gross_amount', 'period_date', 'meta'];

    protected function casts(): array
    {
        return ['amount' => 'integer', 'gross_amount' => 'integer', 'meta' => 'array'];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function drama(): BelongsTo
    {
        return $this->belongsTo(Drama::class);
    }
}
