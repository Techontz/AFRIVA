<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A monthly cost entered by finance (streaming/CDN, storage, hosting, payment fees, other). */
class OperatingCost extends Model
{
    public const CATEGORIES = ['streaming', 'storage', 'hosting', 'payments', 'other'];

    // period stored as Y-m-d string (first day of the month).
    protected $fillable = ['period', 'category', 'amount', 'notes', 'created_by'];

    protected function casts(): array
    {
        return ['amount' => 'integer'];
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
