<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Episode extends Model
{
    protected $fillable = [
        'drama_id', 'number', 'title', 'video_url', 'thumbnail_url', 'duration_seconds', 'is_free', 'views',
    ];

    protected function casts(): array
    {
        return [
            'number' => 'integer',
            'duration_seconds' => 'integer',
            'is_free' => 'boolean',
            'views' => 'integer',
        ];
    }

    public function drama(): BelongsTo
    {
        return $this->belongsTo(Drama::class);
    }

    /** Free if explicitly overridden, else number <= drama.free_episodes. */
    public function isFree(): bool
    {
        $override = $this->getAttributes()['is_free'] ?? null;
        if ($override !== null) {
            return (bool) $override;
        }

        return $this->number <= (int) $this->drama->free_episodes;
    }
}
