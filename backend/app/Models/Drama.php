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
    protected $fillable = [
        'company_id', 'title', 'slug', 'synopsis', 'poster_url', 'backdrop_url', 'total_episodes',
        'free_episodes', 'coins_per_episode', 'status', 'is_featured', 'badge', 'language', 'release_date', 'views',
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

    public function scopePublished(Builder $q): Builder
    {
        return $q->where('status', 'published');
    }

    public function refreshEpisodeCount(): void
    {
        $this->forceFill(['total_episodes' => $this->episodes()->count()])->save();
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
