<?php

namespace App\Http\Controllers\Api\V1\Concerns;

use App\Exceptions\ApiException;
use App\Http\Requests\DramaRequest;
use App\Http\Requests\EpisodeRequest;
use App\Http\Resources\ContentReviewResource;
use App\Http\Resources\DramaResource;
use App\Http\Resources\StudioEpisodeResource;
use App\Models\AuditLog;
use App\Models\Drama;
use App\Models\Episode;
use App\Services\ContentService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Drama + episode CRUD shared by Admin (all companies) and Studio (own company only).
 * Implementors define dramaScope() and may force a company id on writes.
 */
trait ManagesDramas
{
    abstract protected function dramaScope(Request $request): Builder;

    /** Company id forced on create/update (studio), or null to take it from the payload (admin). */
    abstract protected function forcedCompanyId(Request $request): ?int;

    /** True for staff (admin): content is approved on creation and publishing rules may be set. */
    abstract protected function asStaff(): bool;

    /** Creators may only change a series while it is a draft or was sent back for changes. */
    protected function ensureCreatorCanEdit(Drama $drama): void
    {
        if (! $this->asStaff() && ! $drama->isEditableByCreator()) {
            throw new ApiException('Series hii imetumwa kwa ukaguzi au imeidhinishwa, kwa hiyo huwezi kuibadilisha sasa.', 'locked_for_review', 409);
        }
    }

    protected function ensureCreatorCanEditEpisode(Episode $episode): void
    {
        if (! $this->asStaff() && ! $episode->isEditableByCreator()) {
            throw new ApiException('Episode hii imetumwa kwa ukaguzi au imeidhinishwa, kwa hiyo huwezi kuibadilisha sasa.', 'locked_for_review', 409);
        }
    }

    protected function findDrama(Request $request, int|string $id): Drama
    {
        return $this->dramaScope($request)->with(['categories', 'tags', 'company'])->findOrFail($id);
    }

    public function index(Request $request): JsonResponse
    {
        $q = $this->dramaScope($request)->with(['categories', 'tags', 'company'])->withCount('episodes');
        if ($s = trim((string) $request->query('q', ''))) {
            $q->where('title', 'like', "%{$s}%");
        }
        if ($status = $request->query('status')) {
            $q->where('status', $status);
        }
        if ($review = $request->query('review_status')) {
            $q->whereIn('review_status', explode(',', $review));
        }
        if ($companyId = $request->query('company_id')) {
            $q->where('company_id', $companyId);
        }
        if ($cat = $request->query('category')) {
            $q->whereHas('categories', fn ($c) => $c->where('slug', $cat));
        }
        $sort = $request->query('sort', 'newest');
        $sort === 'popular' ? $q->orderByDesc('views') : $q->orderByDesc('id');

        return $this->paginated($q->paginate($this->perPage(25)), DramaResource::class);
    }

    public function store(DramaRequest $request, ContentService $content): JsonResponse
    {
        $data = $request->validated();
        if ($forced = $this->forcedCompanyId($request)) {
            $data['company_id'] = $forced;
        }
        $drama = $content->saveDrama(new Drama, $data, $request, $this->asStaff());

        return $this->ok((new DramaResource($drama))->withReview(), null, 201);
    }

    public function show(Request $request, int $drama): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $episodes = $model->episodes()->get()->each->setRelation('drama', $model);
        $data = (new DramaResource($model))->withReview()->resolve();
        $data['episodes'] = StudioEpisodeResource::collection($episodes);
        $data['reviews'] = ContentReviewResource::collection($model->reviews()->with(['user', 'episode'])->limit(100)->get());

        return $this->ok($data);
    }

    public function update(DramaRequest $request, ContentService $content, int $drama): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $this->ensureCreatorCanEdit($model);
        $data = $request->validated();
        if ($forced = $this->forcedCompanyId($request)) {
            $data['company_id'] = $forced;
        }

        return $this->ok((new DramaResource($content->saveDrama($model, $data, $request, $this->asStaff())))->withReview());
    }

    public function destroy(Request $request, int $drama): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        if (! $this->asStaff() && ($model->status === 'published' || ! in_array($model->review_status, ['draft', 'changes_requested', 'rejected'], true))) {
            throw new ApiException('Series iliyotumwa, iliyoidhinishwa au iliyochapishwa haiwezi kufutwa na mtayarishaji.', 'locked_for_review', 409);
        }
        $model->delete();
        if ($this->asStaff()) {
            AuditLog::record('drama.delete', $model, null, $model->title);
        }

        return $this->ok(['deleted' => true]);
    }

    // ---- Episodes -------------------------------------------------------

    public function episodes(Request $request, int $drama): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $episodes = $model->episodes()->get()->each->setRelation('drama', $model);

        return $this->ok(StudioEpisodeResource::collection($episodes), ['total' => $episodes->count()]);
    }

    public function storeEpisode(EpisodeRequest $request, ContentService $content, int $drama): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        if (! $this->asStaff() && ($model->review_status === Drama::REVIEW_REJECTED || in_array($model->review_status, Drama::REVIEW_PENDING, true))) {
            throw new ApiException('Huwezi kuongeza episode wakati series iko kwenye ukaguzi au imekataliwa.', 'locked_for_review', 409);
        }
        $episode = $content->saveEpisode($model, new Episode, $request->validated(), $request, $this->asStaff());

        return $this->ok(new StudioEpisodeResource($episode), null, 201);
    }

    public function showEpisode(Request $request, int $drama, int $episode): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $ep = $model->episodes()->whereKey($episode)->firstOrFail()->setRelation('drama', $model);

        return $this->ok(new StudioEpisodeResource($ep));
    }

    public function updateEpisode(EpisodeRequest $request, ContentService $content, int $drama, int $episode): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $ep = $model->episodes()->whereKey($episode)->firstOrFail();
        $this->ensureCreatorCanEditEpisode($ep);

        return $this->ok(new StudioEpisodeResource($content->saveEpisode($model, $ep, $request->validated(), $request, $this->asStaff())));
    }

    public function destroyEpisode(Request $request, ContentService $content, int $drama, int $episode): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $ep = $model->episodes()->whereKey($episode)->firstOrFail();
        $this->ensureCreatorCanEditEpisode($ep);
        $content->deleteEpisode($model, $ep, $this->asStaff());

        return $this->ok(['deleted' => true]);
    }

    /** POST dramas/{drama}/episodes/reorder {episode_ids: [...]} → numbers 1..n in that order. */
    public function reorderEpisodes(Request $request, ContentService $content, int $drama): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $this->ensureCreatorCanEdit($model);
        $ids = $request->validate(['episode_ids' => ['required', 'array', 'min:1'], 'episode_ids.*' => ['integer']])['episode_ids'];
        $content->reorderEpisodes($model, $ids);
        $episodes = $model->episodes()->get()->each->setRelation('drama', $model);

        return $this->ok(StudioEpisodeResource::collection($episodes));
    }
}
