<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Drama extends Model
{
    public const REVIEW_DRAFT = 'draft';

    public const REVIEW_SUBMITTED = 'submitted';

    public const REVIEW_IN_REVIEW = 'in_review';

    public const REVIEW_CHANGES = 'changes_requested';

    public const REVIEW_APPROVED = 'approved';

    public const REVIEW_REJECTED = 'rejected';

    public const REVIEW_STATUSES = ['draft', 'submitted', 'in_review', 'changes_requested', 'approved', 'rejected'];

    public const REVIEW_PENDING = ['submitted', 'in_review'];

    public const CREATOR_EDITABLE = ['draft', 'changes_requested'];

    public const ACCESS_MODES = ['coins_or_vip', 'vip_only', 'coins_only'];

    public const AGE_RATINGS = ['all', '7+', '13+', '16+', '18+'];

    /** Scope §02: episodes 1-8 are a free preview unless the admin changes it per series. */
    public const DEFAULT_FREE_EPISODES = 8;

    protected $fillable = [
        'company_id', 'title', 'slug', 'synopsis', 'poster_url', 'backdrop_url', 'total_episodes',
        'free_episodes', 'coins_per_episode', 'status', 'is_featured', 'badge', 'language', 'release_date', 'views',
        'trailer_url', 'age_rating', 'access_mode', 'publish_at', 'review_status', 'review_notes', 'submitted_at',
        'reviewed_at', 'reviewed_by', 'rights_declared_at',
    ];

    protected $attributes = [
        'free_episodes' => self::DEFAULT_FREE_EPISODES,
        'access_mode' => 'coins_or_vip',
        'review_status' => self::REVIEW_DRAFT,
    ];

    protected function casts(): array
    {
        return [
            'is_featured' => 'boolean',
            'total_episodes' => 'integer',
            'free_episodes' => 'integer',
            'coins_per_episode' => 'integer',
            'views' => 'integer',
            'release_date' => 'date:Y-m-d',
            'publish_at' => 'datetime',
            'submitted_at' => 'datetime',
            'reviewed_at' => 'datetime',
            'rights_declared_at' => 'datetime',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function categories(): BelongsToMany
    {
        return $this->belongsToMany(Category::class);
    }

    public function tags(): BelongsToMany
    {
        return $this->belongsToMany(Tag::class);
    }

    public function episodes(): HasMany
    {
        return $this->hasMany(Episode::class)->orderBy('number');
    }

    public function views(): HasMany
    {
        return $this->hasMany(EpisodeView::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(ContentReview::class)->latest('id');
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    /** Live for viewers: published, approved, and its scheduled date (if any) has arrived. */
    public function scopePublished(Builder $q): Builder
    {
        return $q->where('status', 'published')
            ->where('review_status', self::REVIEW_APPROVED)
            ->where(fn ($w) => $w->whereNull('publish_at')->orWhere('publish_at', '<=', now()));
    }

    public function isLive(): bool
    {
        return $this->status === 'published' && $this->review_status === self::REVIEW_APPROVED
            && (! $this->publish_at || $this->publish_at->lte(now()));
    }

    /** Published with a future publish date. */
    public function isScheduled(): bool
    {
        return $this->status === 'published' && $this->publish_at !== null && $this->publish_at->isFuture();
    }

    public function isEditableByCreator(): bool
    {
        return in_array($this->review_status, self::CREATOR_EDITABLE, true);
    }

    /** total_episodes counts only approved episodes, i.e. what viewers can see. */
    public function refreshEpisodeCount(): void
    {
        $this->forceFill(['total_episodes' => $this->episodes()->approved()->count()])->save();
    }

    public static function uniqueSlug(string $title, ?int $ignoreId = null): string
    {
        $base = Str::slug($title) ?: 'drama';
        $slug = $base;
        $i = 2;
        while (static::where('slug', $slug)->when($ignoreId, fn ($q) => $q->where('id', '!=', $ignoreId))->exists()) {
            $slug = $base.'-'.$i++;
        }

        return $slug;
    }
}
