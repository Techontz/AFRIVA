<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EpisodeUnlock extends Model
{
    protected $fillable = ['user_id', 'episode_id', 'method', 'coins_spent', 'subscription_id'];

    protected function casts(): array
    {
        return ['coins_spent' => 'integer'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function episode(): BelongsTo
    {
        return $this->belongsTo(Episode::class);
    }
}
