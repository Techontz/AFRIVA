<?php

namespace App\Http\Resources;

use App\Models\Drama;
use App\Support\VideoUrl;
use App\Support\Viewer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Drama */
class DramaResource extends JsonResource
{
    protected bool $withReview = false;

    /** Include review/publishing workflow fields (always on for admin and studio routes). */
    public function withReview(bool $flag = true): static
    {
        $this->withReview = $flag;

        return $this;
    }

    public function toArray(Request $request): array
    {
        $manage = $this->withReview || $request->is('api/v1/admin/*', 'api/v1/studio/*');

        return [
            'id' => $this->id,
            'slug' => $this->slug,
            'title' => $this->title,
            'synopsis' => $this->synopsis,
            'poster_url' => $this->poster_url,
            'backdrop_url' => $this->backdrop_url,
            'trailer_url' => VideoUrl::forPlayback($this->trailer_url),
            'age_rating' => $this->age_rating,
            'total_episodes' => (int) $this->total_episodes,
            'total_duration_seconds' => $this->when(isset($this->total_duration_seconds), fn () => (int) $this->total_duration_seconds),
            'free_episodes' => (int) $this->free_episodes,
            'coins_per_episode' => (int) $this->coins_per_episode,
            'access_mode' => $this->access_mode,
            'badge' => $this->badge,
            'views' => (int) $this->views,
            'categories' => $this->whenLoaded('categories', fn () => $this->categories->map(fn ($c) => [
                'id' => $c->id, 'name' => $c->name, 'slug' => $c->slug,
            ])->values(), []),
            'tags' => $this->whenLoaded('tags', fn () => $this->tags->pluck('name')->values(), []),
            'company' => $this->whenLoaded('company', fn () => $this->company ? [
                'id' => $this->company->id, 'name' => $this->company->name, 'slug' => $this->company->slug,
            ] : null),
            'is_favorite' => isset(Viewer::favoriteIds()[$this->id]),
            'language' => $this->language,
            'release_date' => $this->release_date?->toDateString(),
            'is_featured' => (bool) $this->is_featured,
            'status' => $this->status,
            'rank' => $this->when(isset($this->rank), fn () => $this->rank),
            'period_views' => $this->when(isset($this->period_views), fn () => (int) $this->period_views),
            'resume' => $this->when(isset($this->resume), fn () => $this->resume),
            'created_at' => $this->created_at?->toIso8601String(),
            $this->mergeWhen($manage, fn () => [
                'publish_at' => $this->publish_at?->toIso8601String(),
                'is_scheduled' => $this->isScheduled(),
                'is_live' => $this->isLive(),
                'review_status' => $this->review_status,
                'review_notes' => $this->review_notes,
                'submitted_at' => $this->submitted_at?->toIso8601String(),
                'reviewed_at' => $this->reviewed_at?->toIso8601String(),
                'rights_declared_at' => $this->rights_declared_at?->toIso8601String(),
                'episodes_count' => $this->when(isset($this->episodes_count), fn () => (int) $this->episodes_count),
                'pending_episodes_count' => $this->when(isset($this->pending_episodes_count), fn () => (int) $this->pending_episodes_count),
            ]),
        ];
    }
}
