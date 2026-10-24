<?php

namespace App\Http\Resources;

use App\Support\Viewer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Drama */
class DramaResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'slug' => $this->slug,
            'title' => $this->title,
            'synopsis' => $this->synopsis,
            'poster_url' => $this->poster_url,
            'backdrop_url' => $this->backdrop_url,
            'total_episodes' => (int) $this->total_episodes,
            'free_episodes' => (int) $this->free_episodes,
            'coins_per_episode' => (int) $this->coins_per_episode,
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
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
