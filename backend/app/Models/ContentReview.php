<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** One step in a series/episode review: submitted, review started, changes requested, approved, rejected, published. */
class ContentReview extends Model
{
    protected $fillable = ['drama_id', 'episode_id', 'user_id', 'action', 'from_status', 'to_status', 'notes'];

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
}
