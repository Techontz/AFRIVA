<?php

namespace App\Http\Controllers\Api\V1\Concerns;

use App\Http\Requests\DramaRequest;
use App\Http\Requests\EpisodeRequest;
use App\Http\Resources\DramaResource;
use App\Http\Resources\StudioEpisodeResource;
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

    protected function findDrama(Request $request, int|string $id): Drama
    {
        return $this->dramaScope($request)->with(['categories', 'tags', 'company'])->findOrFail($id);
    }

    public function index(Request $request): JsonResponse
    {
        $q = $this->dramaScope($request)->with(['categories', 'tags', 'company']);
        if ($s = trim((string) $request->query('q', ''))) {
            $q->where('title', 'like', "%{$s}%");
        }
        if ($status = $request->query('status')) {
            $q->where('status', $status);
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
        $drama = $content->saveDrama(new Drama, $data, $request);

        return $this->ok(new DramaResource($drama), null, 201);
    }

    public function show(Request $request, int $drama): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $episodes = $model->episodes()->get()->each->setRelation('drama', $model);
        $data = (new DramaResource($model))->resolve();
        $data['episodes'] = StudioEpisodeResource::collection($episodes);

        return $this->ok($data);
    }

    public function update(DramaRequest $request, ContentService $content, int $drama): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $data = $request->validated();
        if ($forced = $this->forcedCompanyId($request)) {
            $data['company_id'] = $forced;
        }

        return $this->ok(new DramaResource($content->saveDrama($model, $data, $request)));
    }

    public function destroy(Request $request, int $drama): JsonResponse
    {
        $this->findDrama($request, $drama)->delete();

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
        $episode = $content->saveEpisode($model, new Episode, $request->validated(), $request);

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

        return $this->ok(new StudioEpisodeResource($content->saveEpisode($model, $ep, $request->validated(), $request)));
    }

    public function destroyEpisode(Request $request, ContentService $content, int $drama, int $episode): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $content->deleteEpisode($model, $model->episodes()->whereKey($episode)->firstOrFail());

        return $this->ok(['deleted' => true]);
    }
}
