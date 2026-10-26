<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Episode;
use App\Services\VideoProcessor;
use App\Support\VideoUrl;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Video Library: every episode video with its processing state; retry transcoding. */
class VideoController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $q = Episode::query()->with('drama:id,title,slug,poster_url,company_id', 'drama.company:id,name');
        if ($status = $request->query('video_status')) {
            $q->where('video_status', $status);
        }
        if ($review = $request->query('review_status')) {
            $q->where('review_status', $review);
        }
        if ($request->boolean('unverified')) {
            $q->whereNull('playback_verified_at');
        }
        if ($s = trim((string) $request->query('q', ''))) {
            $q->whereHas('drama', fn ($d) => $d->where('title', 'like', "%{$s}%"));
        }
        $page = $q->orderByDesc('updated_at')->paginate($this->perPage(30));

        $counts = Episode::query()->selectRaw('video_status, COUNT(*) as c')->groupBy('video_status')->pluck('c', 'video_status')->map(fn ($v) => (int) $v);

        return $this->ok($page->getCollection()->map(fn (Episode $e) => [
            'id' => $e->id,
            'number' => $e->number,
            'title' => $e->title,
            'drama' => $e->drama ? ['id' => $e->drama->id, 'title' => $e->drama->title, 'slug' => $e->drama->slug, 'poster_url' => $e->drama->poster_url,
                'company' => $e->drama->company?->name] : null,
            'thumbnail_url' => $e->thumbnail_url,
            'duration_seconds' => (int) $e->duration_seconds,
            'is_uploaded' => VideoUrl::isPrivate($e->video_url),
            'video_status' => $e->video_status,
            'video_error' => $e->video_error,
            'renditions' => $e->renditions ?? [],
            'source_size' => $e->source_size,
            'subtitle_url' => $e->subtitle_url,
            'review_status' => $e->review_status,
            'playback_verified_at' => $e->playback_verified_at?->toIso8601String(),
            'sources' => $e->video_url ? VideoUrl::sources($e) : [],
            'updated_at' => $e->updated_at?->toIso8601String(),
        ])->values(), [
            'current_page' => $page->currentPage(),
            'last_page' => $page->lastPage(),
            'per_page' => $page->perPage(),
            'total' => $page->total(),
            'counts' => $counts,
            'transcoding_enabled' => (bool) config('media.transcode'),
        ]);
    }

    /** POST /admin/videos/{episode}/reprocess */
    public function reprocess(int $episode, VideoProcessor $videos): JsonResponse
    {
        $ep = Episode::with('drama')->findOrFail($episode);
        $videos->queue($ep);
        AuditLog::record('episode.reprocess_video', $ep, null, "{$ep->drama?->title} · Episode {$ep->number}");

        return $this->ok(['id' => $ep->id, 'video_status' => $ep->fresh()->video_status]);
    }
}
