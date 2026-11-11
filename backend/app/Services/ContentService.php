<?php

namespace App\Services;

use App\Models\Drama;
use App\Models\Episode;
use App\Models\Tag;
use App\Support\CatalogCache;
use App\Support\WebpImage;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Create/update dramas & episodes (shared by Admin and Studio controllers), incl. file uploads to the public disk.
 */
class ContentService
{
    public function __construct(protected BunnyStream $bunny) {}

    /** Square-ish images (fit in 512x512); everything else is a poster/thumbnail/backdrop (720x1280 or 1280x720). */
    protected const SMALL_IMAGE_DIRS = ['logos', 'avatars', 'payment-methods'];

    /**
     * Stores a public upload. Images are converted to WebP (downscaled first) to save space and bandwidth;
     * if GD cannot do it the original file is stored. Videos and other files are stored unchanged.
     */
    public function storeFile(UploadedFile $file, string $dir): string
    {
        if (WebpImage::isImage($file)) {
            [$w, $h] = in_array($dir, self::SMALL_IMAGE_DIRS, true) ? [512, 512] : $this->posterBox($file);
            $webp = WebpImage::encode($file, $w, $h);
            if ($webp !== null) {
                $path = trim($dir, '/').'/'.Str::random(40).'.webp';
                Storage::disk('public')->put($path, $webp, ['visibility' => 'public', 'ContentType' => 'image/webp']);

                return Storage::disk('public')->url($path);
            }
        }
        $path = $file->store($dir, 'public');

        return Storage::disk('public')->url($path);
    }

    /** @return array{0:int,1:int} 720x1280 for portrait images, 1280x720 for landscape. */
    protected function posterBox(UploadedFile $file): array
    {
        $size = @getimagesize($file->getRealPath());

        return $size && $size[0] > $size[1] ? [1280, 720] : [720, 1280];
    }

    public function saveDrama(Drama $drama, array $data, Request $request): Drama
    {
        return DB::transaction(function () use ($drama, $data, $request) {
            $fields = collect($data)->only([
                'company_id', 'title', 'synopsis', 'poster_url', 'backdrop_url', 'free_episodes', 'coins_per_episode',
                'status', 'is_featured', 'badge', 'language', 'release_date',
            ])->all();
            // Clients may echo back signed CDN URLs from our responses: store them unsigned.
            foreach (['poster_url', 'backdrop_url'] as $key) {
                if (array_key_exists($key, $fields)) {
                    $fields[$key] = $this->bunny->unsignUrl($fields[$key]);
                }
            }

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
            // Pivot syncs fire no model events: invalidate the public catalogue cache once they have committed.
            DB::afterCommit(fn () => CatalogCache::flush());

            return $drama->load(['categories', 'tags', 'company']);
        });
    }

    public function saveEpisode(Drama $drama, Episode $episode, array $data, Request $request): Episode
    {
        $displaced = [];

        $saved = DB::transaction(function () use ($drama, $episode, $data, $request, &$displaced) {
            $previousUrl = $episode->video_url;
            $previousGuid = $episode->bunny_video_id;
            $fields = collect($data)->only(['number', 'title', 'video_url', 'thumbnail_url', 'duration_seconds', 'orientation'])->all();
            foreach (['video_url', 'thumbnail_url'] as $key) {
                if (array_key_exists($key, $fields)) {
                    $fields[$key] = $this->bunny->unsignUrl($fields[$key]);
                }
            }
            $episode->fill($fields);
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
                throw ValidationException::withMessages([
                    'number' => [__('api.episode_number_taken', ['number' => $episode->number])],
                ]);
            }

            if ($request->hasFile('video')) {
                $episode->video_url = $this->storeFile($request->file('video'), 'videos');
            }
            if ($request->hasFile('thumbnail')) {
                $episode->thumbnail_url = $this->storeFile($request->file('thumbnail'), 'thumbnails');
            }
            // A pasted URL (or a direct file upload) replaces any Bunny video: it is ready as is.
            if ($episode->isDirty('video_url')) {
                $episode->video_status = filled($episode->video_url) ? 'ready' : 'none';
                $episode->bunny_video_id = null;
                $keep = $this->bunny->guidFromUrl($episode->video_url);
                $displaced = array_values(array_filter(
                    array_unique([$previousGuid, $this->bunny->guidFromUrl($previousUrl)]),
                    fn ($guid) => $guid && $guid !== $keep,
                ));
            }
            $episode->title ??= "Episode {$episode->number}";
            $episode->thumbnail_url ??= $drama->poster_url;
            $episode->save();

            $drama->refreshEpisodeCount();
            $episode->setRelation('drama', $drama);

            return $episode;
        });

        $this->bunny->deleteVideos($displaced);

        return $saved;
    }

    public function deleteEpisode(Drama $drama, Episode $episode): void
    {
        $guids = $this->bunnyGuids($episode);
        $episode->delete();
        $drama->refreshEpisodeCount();
        $this->bunny->deleteVideos($guids);
    }

    /** Deleting a drama cascades to its episodes in the database; remove their Bunny videos too. */
    public function deleteDrama(Drama $drama): void
    {
        $guids = $drama->episodes()->get(['id', 'bunny_video_id', 'video_url'])
            ->flatMap(fn (Episode $ep) => $this->bunnyGuids($ep))->all();
        $drama->delete();
        $this->bunny->deleteVideos($guids);
    }

    /** @return array<int,string> */
    protected function bunnyGuids(Episode $episode): array
    {
        return array_values(array_filter(array_unique([$episode->bunny_video_id, $this->bunny->guidFromUrl($episode->video_url)])));
    }
}
