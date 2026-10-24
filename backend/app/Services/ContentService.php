<?php

namespace App\Services;

use App\Models\Drama;
use App\Models\Episode;
use App\Models\Tag;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Create/update dramas & episodes (shared by Admin and Studio controllers), incl. file uploads to the public disk.
 */
class ContentService
{
    public function storeFile(UploadedFile $file, string $dir): string
    {
        $path = $file->store($dir, 'public');

        return Storage::disk('public')->url($path);
    }

    public function saveDrama(Drama $drama, array $data, Request $request): Drama
    {
        return DB::transaction(function () use ($drama, $data, $request) {
            $fields = collect($data)->only([
                'company_id', 'title', 'synopsis', 'poster_url', 'backdrop_url', 'free_episodes', 'coins_per_episode',
                'status', 'is_featured', 'badge', 'language', 'release_date',
            ])->all();

            $drama->fill($fields);

            if (! empty($data['slug'])) {
                $drama->slug = Drama::uniqueSlug($data['slug'], $drama->id);
            } elseif (! $drama->slug) {
                $drama->slug = Drama::uniqueSlug($drama->title);
            }

            if ($request->hasFile('poster')) {
                $drama->poster_url = $this->storeFile($request->file('poster'), 'posters');
            }
            if ($request->hasFile('backdrop')) {
                $drama->backdrop_url = $this->storeFile($request->file('backdrop'), 'backdrops');
            }
            $drama->poster_url ??= "https://picsum.photos/seed/afriva-{$drama->slug}/600/800";
            $drama->backdrop_url ??= "https://picsum.photos/seed/afriva-{$drama->slug}-bg/1280/720";
            $drama->status ??= 'draft';
            $drama->language ??= 'sw';

            $drama->save();

            if (array_key_exists('category_ids', $data)) {
                $drama->categories()->sync($data['category_ids'] ?? []);
            }
            if (array_key_exists('tags', $data)) {
                $drama->tags()->sync(Tag::idsFor($data['tags'] ?? []));
            }

            return $drama->load(['categories', 'tags', 'company']);
        });
    }

    public function saveEpisode(Drama $drama, Episode $episode, array $data, Request $request): Episode
    {
        return DB::transaction(function () use ($drama, $episode, $data, $request) {
            $episode->fill(collect($data)->only(['number', 'title', 'video_url', 'thumbnail_url', 'duration_seconds'])->all());
            if (array_key_exists('is_free', $data)) {
                $episode->is_free = $data['is_free'];
            }
            $episode->drama_id = $drama->id;

            if (! $episode->number) {
                $episode->number = ((int) $drama->episodes()->max('number')) + 1;
            }
            $clash = Episode::where('drama_id', $drama->id)->where('number', $episode->number)
                ->when($episode->exists, fn ($q) => $q->where('id', '!=', $episode->id))->exists();
            if ($clash) {
                throw \Illuminate\Validation\ValidationException::withMessages([
                    'number' => ["Episode {$episode->number} already exists for this drama."],
                ]);
            }

            if ($request->hasFile('video')) {
                $episode->video_url = $this->storeFile($request->file('video'), 'videos');
            }
            if ($request->hasFile('thumbnail')) {
                $episode->thumbnail_url = $this->storeFile($request->file('thumbnail'), 'thumbnails');
            }
            $episode->title ??= "Episode {$episode->number}";
            $episode->thumbnail_url ??= $drama->poster_url;
            $episode->save();

            $drama->refreshEpisodeCount();
            $episode->setRelation('drama', $drama);

            return $episode;
        });
    }

    public function deleteEpisode(Drama $drama, Episode $episode): void
    {
        $episode->delete();
        $drama->refreshEpisodeCount();
    }
}
