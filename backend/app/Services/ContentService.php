<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\Drama;
use App\Models\Episode;
use App\Models\Setting;
use App\Models\Tag;
use App\Support\VideoUrl;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

/**
 * Create/update dramas & episodes (shared by Admin and Studio controllers), incl. file uploads
 * (images and subtitles to the public disk, videos and trailers to the private "videos" disk).
 *
 * $asStaff: admin-created content is approved on creation (staff are the reviewers); creator content starts as a draft.
 */
class ContentService
{
    /** Publishing rules only staff may set (scope §04: "admin apange tarehe, bei na episodes za bure"). */
    public const STAFF_ONLY_FIELDS = ['status', 'publish_at', 'free_episodes', 'coins_per_episode', 'access_mode', 'is_featured', 'badge', 'release_date'];

    public function __construct(protected VideoProcessor $videos) {}

    public function storeFile(UploadedFile $file, string $dir): string
    {
        $path = $file->store($dir, 'public');

        return Storage::disk('public')->url($path);
    }

    public function saveDrama(Drama $drama, array $data, Request $request, bool $asStaff = false): Drama
    {
        return DB::transaction(function () use ($drama, $data, $request, $asStaff) {
            $creating = ! $drama->exists;
            $allowed = ['company_id', 'title', 'synopsis', 'poster_url', 'backdrop_url', 'age_rating', 'language'];
            if ($asStaff) {
                $allowed = array_merge($allowed, self::STAFF_ONLY_FIELDS);
            }
            $drama->fill(collect($data)->only($allowed)->all());

            if (array_key_exists('trailer_url', $data)) {
                $drama->trailer_url = VideoUrl::fromInput($data['trailer_url'], $drama->trailer_url);
            }

            if ($asStaff && ($data['status'] ?? null) === 'published') {
                if (! $creating && $drama->review_status !== Drama::REVIEW_APPROVED) {
                    throw ValidationException::withMessages(['status' => ['Series lazima iidhinishwe kabla ya kuchapishwa.']]);
                }
            }

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
            if ($request->hasFile('trailer')) {
                $drama->trailer_url = VideoUrl::store($request->file('trailer'), 'trailers');
            }
            $drama->backdrop_url ??= $drama->poster_url;
            $drama->status ??= 'draft';
            $drama->language ??= 'sw';

            if ($creating) {
                if (! $asStaff || ! isset($data['free_episodes'])) {
                    $drama->free_episodes = (int) Setting::get('default_free_episodes', Drama::DEFAULT_FREE_EPISODES);
                }
                if (! $asStaff || ! isset($data['coins_per_episode'])) {
                    $drama->coins_per_episode = (int) Setting::get('default_coins_per_episode', 30);
                }
                $drama->review_status = $asStaff ? Drama::REVIEW_APPROVED : Drama::REVIEW_DRAFT;
                if ($asStaff) {
                    $drama->reviewed_at = now();
                    $drama->reviewed_by = $request->user()?->id;
                }
            }

            $drama->save();

            if (array_key_exists('category_ids', $data)) {
                $drama->categories()->sync($data['category_ids'] ?? []);
            }
            if (array_key_exists('tags', $data)) {
                $drama->tags()->sync(Tag::idsFor($data['tags'] ?? []));
            }

            if ($asStaff) {
                $diff = AuditLog::diff($drama, ['status', 'publish_at', 'free_episodes', 'coins_per_episode', 'access_mode', 'is_featured', 'title']);
                if ($creating || $diff) {
                    AuditLog::record($creating ? 'drama.create' : 'drama.update', $drama, $creating ? null : $diff, $drama->title);
                }
            }

            return $drama->load(['categories', 'tags', 'company']);
        });
    }

    public function saveEpisode(Drama $drama, Episode $episode, array $data, Request $request, bool $asStaff = false): Episode
    {
        $videoChanged = false;

        $episode = DB::transaction(function () use ($drama, $episode, $data, $request, $asStaff, &$videoChanged) {
            $creating = ! $episode->exists;
            $previousVideo = $episode->video_url;

            if (array_key_exists('video_url', $data)) {
                $data['video_url'] = VideoUrl::fromInput($data['video_url'], $episode->video_url);
            }
            $fields = ['number', 'title', 'video_url', 'thumbnail_url', 'duration_seconds', 'subtitle_url'];
            $episode->fill(collect($data)->only($fields)->all());
            if ($asStaff && array_key_exists('is_free', $data)) {
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
                    'number' => ["Episode {$episode->number} tayari ipo kwenye series hii."],
                ]);
            }

            if ($request->hasFile('video')) {
                $file = $request->file('video');
                $episode->video_url = VideoUrl::store($file);
                $episode->source_size = $file->getSize();
            }
            if ($request->hasFile('thumbnail')) {
                $episode->thumbnail_url = $this->storeFile($request->file('thumbnail'), 'thumbnails');
            }
            if ($request->hasFile('subtitle')) {
                $episode->subtitle_url = $this->storeFile($request->file('subtitle'), 'subtitles');
            }
            $episode->title ??= "Episode {$episode->number}";
            $episode->thumbnail_url ??= $drama->poster_url;

            $videoChanged = $episode->video_url !== $previousVideo;
            if ($videoChanged) {
                // A new file has to be checked again before it can be approved.
                $episode->playback_verified_at = $asStaff ? now() : null;
            }
            if ($creating) {
                $episode->review_status = $asStaff ? Drama::REVIEW_APPROVED : Drama::REVIEW_DRAFT;
            }
            $episode->save();

            $drama->refreshEpisodeCount();
            $episode->setRelation('drama', $drama);

            if ($asStaff) {
                AuditLog::record($creating ? 'episode.create' : ($videoChanged ? 'episode.replace_video' : 'episode.update'), $episode,
                    $creating ? null : AuditLog::diff($episode, ['number', 'title', 'is_free', 'video_url']),
                    "{$drama->title} · Episode {$episode->number}");
            }

            return $episode;
        });

        if ($videoChanged && $episode->video_url) {
            $this->videos->queue($episode);
        }

        return $episode;
    }

    public function deleteEpisode(Drama $drama, Episode $episode, bool $asStaff = false): void
    {
        $episode->delete();
        $drama->refreshEpisodeCount();
        if ($asStaff) {
            AuditLog::record('episode.delete', $episode, null, "{$drama->title} · Episode {$episode->number}");
        }
    }

    /**
     * Renumber a drama's episodes 1..n in the given order.
     *
     * @param  list<int>  $episodeIds
     */
    public function reorderEpisodes(Drama $drama, array $episodeIds): void
    {
        $existing = $drama->episodes()->pluck('id')->map(fn ($id) => (int) $id)->sort()->values()->all();
        $given = collect($episodeIds)->map(fn ($id) => (int) $id);
        if ($given->sort()->values()->all() !== $existing) {
            throw ValidationException::withMessages(['episode_ids' => ['Orodha lazima iwe na episode zote za series hii, kila moja mara moja.']]);
        }

        DB::transaction(function () use ($drama, $given) {
            // Two passes so the unique (drama_id, number) index never sees a duplicate.
            foreach ($given as $i => $id) {
                Episode::whereKey($id)->update(['number' => -($i + 1)]);
            }
            foreach ($given as $i => $id) {
                Episode::whereKey($id)->update(['number' => $i + 1]);
            }
            AuditLog::record('episode.reorder', $drama, ['order' => $given->all()], $drama->title);
        });
    }
}
