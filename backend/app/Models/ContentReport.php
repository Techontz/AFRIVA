<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A viewer's report about a series: copyright infringement, inappropriate or misleading content. */
class ContentReport extends Model
{
    public const REASONS = ['copyright', 'inappropriate', 'misleading', 'other'];

    protected $fillable = [
        'drama_id', 'episode_id', 'user_id', 'reason', 'details', 'contact', 'status', 'resolved_by', 'resolution_notes', 'resolved_at',
    ];

    protected function casts(): array
    {
        return ['resolved_at' => 'datetime'];
    }

    public function drama(): BelongsTo
    {
        return $this->belongsTo(Drama::class);
    }

    public function episode(): BelongsTo
    {
        return $this->belongsTo(Episode::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function resolver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'resolved_by');
    }
}
