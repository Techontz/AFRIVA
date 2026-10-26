<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\ContentReviewResource;
use App\Http\Resources\DramaResource;
use App\Http\Resources\StudioEpisodeResource;
use App\Models\Drama;
use App\Models\Episode;
use App\Services\ReviewService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Review queue: creators' submissions waiting for a reviewer (scope §04 "Kagua"). */
class ReviewController extends Controller
{
    public function __construct(protected ReviewService $reviews) {}

    /** GET /admin/reviews?status=pending|changes_requested|rejected|approved|all */
    public function index(Request $request): JsonResponse
    {
        $status = $request->query('status', 'pending');
        $pending = fn ($q) => $q->whereIn('review_status', Drama::REVIEW_PENDING);

        $q = Drama::query()->with(['categories', 'tags', 'company'])
            ->withCount(['episodes', 'episodes as pending_episodes_count' => $pending]);
        match ($status) {
            'all' => null,
            'pending' => $q->where(fn ($w) => $w->whereIn('review_status', Drama::REVIEW_PENDING)->orWhereHas('episodes', $pending)),
            default => $q->where('review_status', $status),
        };
        if ($s = trim((string) $request->query('q', ''))) {
            $q->where('title', 'like', "%{$s}%");
        }

        return $this->paginated($q->orderByRaw('submitted_at IS NULL')->orderBy('submitted_at')->paginate($this->perPage(25)), DramaResource::class, [
            'counts' => [
                'pending' => Drama::where(fn ($w) => $w->whereIn('review_status', Drama::REVIEW_PENDING)->orWhereHas('episodes', $pending))->count(),
                'changes_requested' => Drama::where('review_status', Drama::REVIEW_CHANGES)->count(),
                'rejected' => Drama::where('review_status', Drama::REVIEW_REJECTED)->count(),
            ],
        ]);
    }

    /** GET /admin/reviews/{drama}: everything a reviewer needs: details, episodes (with playable sources), history. */
    public function show(int $drama): JsonResponse
    {
        $model = Drama::with(['categories', 'tags', 'company'])->findOrFail($drama);
        $episodes = $model->episodes()->get()->each->setRelation('drama', $model);
        $data = (new DramaResource($model))->withReview()->resolve();
        $data['episodes'] = StudioEpisodeResource::collection($episodes);
        $data['reviews'] = ContentReviewResource::collection($model->reviews()->with(['user', 'episode'])->limit(100)->get());
        $data['company_agreement_accepted'] = $model->company?->hasAcceptedAgreement() ?? false;

        return $this->ok($data);
    }

    public function start(Request $request, int $drama): JsonResponse
    {
        $this->reviews->startReview(Drama::findOrFail($drama), $request->user());

        return $this->show($drama);
    }

    /** POST /admin/reviews/{drama}/decide {decision: approve|request_changes|reject, notes?, episode_ids?} */
    public function decide(Request $request, int $drama): JsonResponse
    {
        $data = $request->validate([
            'decision' => ['required', 'in:approve,request_changes,reject'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'episode_ids' => ['nullable', 'array'],
            'episode_ids.*' => ['integer'],
        ]);
        $this->reviews->decide(Drama::findOrFail($drama), $request->user(), $data['decision'], $data['notes'] ?? null, $data['episode_ids'] ?? null);

        return $this->show($drama);
    }

    /** POST /admin/episodes/{episode}/verify-playback */
    public function verifyPlayback(Request $request, int $episode): JsonResponse
    {
        $ep = Episode::with('drama')->findOrFail($episode);

        return $this->ok(new StudioEpisodeResource($this->reviews->verifyPlayback($ep, $request->user())));
    }
}
