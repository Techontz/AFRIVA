<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WatchHistory extends Model
{
    protected $fillable = ['user_id', 'drama_id', 'episode_id', 'progress_seconds'];

    protected function casts(): array
    {
        return ['progress_seconds' => 'integer'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function drama(): BelongsTo
    {
        return $this->belongsTo(Drama::class);
    }

    public function episode(): BelongsTo
    {
        return $this->belongsTo(Episode::class);
    }
}
