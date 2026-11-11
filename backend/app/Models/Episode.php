<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Episode extends Model
{
    protected $fillable = [
        'drama_id', 'number', 'title', 'video_url', 'thumbnail_url', 'duration_seconds', 'orientation', 'is_free', 'views',
    ];

    public const VIDEO_STATUSES = ['none', 'uploading', 'processing', 'ready', 'failed'];

    public const ORIENTATIONS = ['portrait', 'landscape'];

    /** bunny_video_id / video_status are managed by the upload flow and BunnyStream, never mass assigned. */
    protected $attributes = [
        'video_status' => 'none',
        'orientation' => 'portrait',
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

    protected static function booted(): void
    {
        // A plain URL set without the upload flow (seeders, imports) is playable as is.
        static::saving(function (Episode $episode) {
            if (($episode->video_status ?? 'none') === 'none' && filled($episode->video_url)) {
                $episode->video_status = 'ready';
            }
        });
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
