<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** One playback of one episode, built from the player's analytics events (watch time, furthest position, completion, errors). */
class WatchSession extends Model
{
    // watched_on stored as Y-m-d string (no date cast) for DB-agnostic grouping.
    protected $fillable = [
        'session_key', 'user_id', 'device_id', 'actor_key', 'episode_id', 'drama_id', 'company_id', 'watched_on',
        'watch_seconds', 'max_position', 'duration_seconds', 'completed', 'errors', 'last_quality',
    ];

    protected function casts(): array
    {
        return [
            'watch_seconds' => 'integer',
            'max_position' => 'integer',
            'duration_seconds' => 'integer',
            'completed' => 'boolean',
            'errors' => 'integer',
        ];
    }

    public function episode(): BelongsTo
    {
        return $this->belongsTo(Episode::class);
    }

    public function drama(): BelongsTo
    {
        return $this->belongsTo(Drama::class);
    }
}
