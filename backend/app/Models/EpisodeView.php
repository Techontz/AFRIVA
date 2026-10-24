<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EpisodeView extends Model
{
    // viewed_on is stored as a plain Y-m-d string (no date cast) so grouping is identical on MySQL & SQLite.
    protected $fillable = ['episode_id', 'drama_id', 'company_id', 'user_id', 'viewed_on'];

    public function episode(): BelongsTo
    {
        return $this->belongsTo(Episode::class);
    }

    public function drama(): BelongsTo
    {
        return $this->belongsTo(Drama::class);
    }
}
