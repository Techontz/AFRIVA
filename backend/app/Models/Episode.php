<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Episode extends Model
{
    protected $fillable = [
        'drama_id', 'number', 'title', 'video_url', 'thumbnail_url', 'duration_seconds', 'is_free', 'views',
        'review_status', 'review_notes', 'playback_verified_at', 'video_status', 'video_error', 'hls_path', 'renditions',
        'subtitle_url', 'source_size',
    ];

    protected function casts(): array
    {
        return [
            'number' => 'integer',
            'duration_seconds' => 'integer',
            'is_free' => 'boolean',
            'views' => 'integer',
            'playback_verified_at' => 'datetime',
            'renditions' => 'array',
            'source_size' => 'integer',
        ];
    }

    public function drama(): BelongsTo
    {
        return $this->belongsTo(Drama::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(ContentReview::class)->latest();
    }

    /** Visible to viewers: approved by a reviewer. */
    public function scopeApproved(Builder $q): Builder
    {
        return $q->where('review_status', Drama::REVIEW_APPROVED);
    }

    public function isApproved(): bool
    {
        return $this->review_status === Drama::REVIEW_APPROVED;
    }

    /** Creators may only change an episode that is still a draft or was sent back for changes. */
    public function isEditableByCreator(): bool
    {
        return in_array($this->review_status, Drama::CREATOR_EDITABLE, true);
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
