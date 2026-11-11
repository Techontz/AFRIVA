<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\CategoryResource;
use App\Http\Resources\DramaResource;
use App\Http\Resources\EpisodeResource;
use App\Http\Resources\PaymentMethodResource;
use App\Http\Resources\PlanResource;
use App\Models\Category;
use App\Models\Drama;
use App\Models\PaymentMethod;
use App\Models\Setting;
use App\Models\Plan;
use App\Services\EpisodeAccessService;
use App\Support\CatalogCache;
use App\Support\Viewer;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Lang;

/**
 * Public catalogue: home, categories, dramas, rankings, detail, feed, plans, payment methods.
 */
class CatalogController extends Controller
{
    protected function base(): Builder
    {
        return Drama::query()->published()->with([
            'categories:id,name,slug',
            'tags:id,name',
            'company:id,name,slug',
        ]);
    }

    /**
     * Resolves dramas to plain arrays (cache friendly). is_favorite is per viewer, so it is re-applied by
     * withFavorites() after reading from the cache.
     *
     * @param  iterable<Drama>  $dramas
     * @return list<array<string,mixed>>
     */
    protected function toArrays(iterable $dramas): array
    {
        $out = [];
        foreach ($dramas as $drama) {
            $out[] = json_decode(json_encode((new DramaResource($drama))->resolve()), true);
        }

        return $out;
    }

    /**
     * @param  list<array<string,mixed>>  $dramas
     * @return list<array<string,mixed>>
     */
    protected function withFavorites(array $dramas): array
    {
        $favorites = Viewer::favoriteIds();

        return array_map(fn (array $d) => array_merge($d, ['is_favorite' => isset($favorites[$d['id']])]), $dramas);
    }

    public function home(): JsonResponse
    {
        $home = CatalogCache::remember('home', fn () => $this->buildHome());

        $sections = [];
        foreach ($home['sections'] as $section) {
            $key = 'catalog.sections.'.$section['key'];
            $section['title'] = Lang::has($key) ? __($key) : ($section['category_name'] ?? $section['key']);
            unset($section['category_name']);
            $section['dramas'] = $this->withFavorites($section['dramas']);
            $sections[] = $section;
        }

        return $this->ok([
            'banners' => $this->withFavorites($home['banners']),
            'sections' => $sections,
        ]);
    }

    /**
     * Collects the drama ids of every home row with light id-only queries, then loads all of those dramas
     * (with relations) in a single pass instead of eager loading per row.
     */
    protected function buildHome(): array
    {
        $ids = fn (Builder $q, int $limit) => $q->limit($limit)->pluck('id')->all();
        $published = fn () => Drama::query()->published();

        $banners = $ids($published()->where('is_featured', true)->orderByDesc('views'), 6);
        if (! $banners) {
            $banners = $ids($published()->orderByDesc('views'), 5);
        }

        $trending = $this->rankedIds('trending', 10);
        $rows = [
            ['key' => 'must_watch', 'layout' => 'row',
                'ids' => $ids($published()->where(fn ($q) => $q->where('badge', 'hot')->orWhere('is_featured', true))->orderByDesc('views'), 12)],
            ['key' => 'trending', 'layout' => 'ranking', 'ids' => array_keys($trending)],
            ['key' => 'new_releases', 'layout' => 'row', 'ids' => $ids($published()->orderByDesc('release_date')->orderByDesc('id'), 12)],
            ['key' => 'hidden_gems', 'layout' => 'row', 'ids' => $ids($published()->orderBy('views'), 12)],
        ];
        // One row per category that has published dramas, in the admin's category order.
        $categories = Category::query()->orderBy('sort_order')->orderBy('id')
            ->whereHas('dramas', fn ($q) => $q->published())->limit(8)->get(['id', 'name', 'slug']);
        foreach ($categories as $category) {
            $catIds = $ids($published()->whereHas('categories', fn ($q) => $q->whereKey($category->id))->orderByDesc('views'), 12);
            $rows[] = ['key' => str_replace('-', '_', $category->slug), 'layout' => 'row', 'ids' => $catIds,
                'category' => $category->slug, 'category_name' => $category->name];
        }
        $rows[] = ['key' => 'popular', 'layout' => 'grid', 'ids' => $ids($published()->orderByDesc('views'), 18)];

        $allIds = array_unique(array_merge($banners, ...array_column($rows, 'ids')));
        $byId = [];
        foreach ($this->base()->whereIn('id', $allIds)->get() as $drama) {
            $byId[$drama->id] = $this->toArrays([$drama])[0];
        }
        $pick = fn (array $list) => array_values(array_filter(array_map(fn ($id) => $byId[$id] ?? null, $list)));

        $sections = [];
        foreach ($rows as $row) {
            $dramas = $pick($row['ids']);
            if ($row['key'] === 'trending') {
                $dramas = $this->withRank($dramas, $trending);
            }
            $section = ['key' => $row['key'], 'title' => null, 'layout' => $row['layout'], 'dramas' => $dramas];
            if (isset($row['category'])) {
                $section['category'] = $row['category'];
                $section['category_name'] = $row['category_name'];
            }
            $sections[] = $section;
        }

        return ['banners' => $pick($banners), 'sections' => $sections];
    }

    /** Public links the admin manages in Settings (empty values are left for the client to hide). */
    public function siteInfo(): JsonResponse
    {
        return $this->ok(CatalogCache::remember('site_info', fn () => [
            'social' => [
                'facebook' => (string) Setting::get('social_facebook'),
                'youtube' => (string) Setting::get('social_youtube'),
                'tiktok' => (string) Setting::get('social_tiktok'),
                'instagram' => (string) Setting::get('social_instagram'),
            ],
        ]));
    }

    public function categories(): JsonResponse
    {
        return $this->ok(CatalogCache::remember('categories', fn () => json_decode(json_encode(CategoryResource::collection(
            Category::withCount(['dramas' => fn ($q) => $q->where('status', 'published')])->orderBy('sort_order')->orderBy('name')->get()
        )->resolve()), true)));
    }

    public function dramas(Request $request): JsonResponse
    {
        $q = $this->base();

        if ($cat = $request->query('category')) {
            if ($cat !== 'all') {
                $q->whereHas('categories', fn ($c) => $c->where('slug', $cat));
            }
        }
        if ($tag = $request->query('tag')) {
            $q->whereHas('tags', fn ($t) => $t->where('slug', $tag)->orWhere('name', $tag));
        }
        if ($badge = $request->query('badge')) {
            $q->where('badge', $badge);
        }
        if ($search = trim((string) $request->query('q', ''))) {
            $like = '%'.str_replace(['%', '_'], ['\%', '\_'], $search).'%';
            $q->where(fn ($w) => $w->where('title', 'like', $like)
                ->orWhere('synopsis', 'like', $like)
                ->orWhereHas('tags', fn ($t) => $t->where('name', 'like', $like)));
        }

        match ($request->query('sort', 'popular')) {
            'newest' => $q->orderByDesc('release_date')->orderByDesc('id'),
            default => $q->orderByDesc('views')->orderByDesc('id'),
        };

        return $this->paginated($q->paginate($this->perPage(24, 60)), DramaResource::class);
    }

    public function rankings(Request $request): JsonResponse
    {
        $type = in_array($request->query('type'), ['trending', 'new', 'popular'], true) ? $request->query('type') : 'trending';
        $limit = max(1, min(50, (int) $request->query('limit', 10)));

        $dramas = CatalogCache::remember("rankings:{$type}:{$limit}", function () use ($type, $limit) {
            $ranked = $this->rankedIds($type, $limit);
            $byId = $this->base()->whereIn('id', array_keys($ranked))->get()->keyBy('id');
            $dramas = $this->toArrays(array_filter(array_map(fn ($id) => $byId[$id] ?? null, array_keys($ranked))));

            return $this->withRank($dramas, $ranked);
        });

        return $this->ok($this->withFavorites($dramas), ['type' => $type]);
    }

    /**
     * Ranked drama ids in order, mapped to their period views (trending) or null.
     * trending = most views in the last 7 days; new = most viewed released in the last 60 days; popular = all-time views.
     *
     * @return array<int,int|null>
     */
    protected function rankedIds(string $type, int $limit): array
    {
        $published = fn () => Drama::query()->published();

        if ($type === 'trending') {
            $since = now()->subDays(6)->toDateString();
            $counts = DB::table('episode_views')->where('viewed_on', '>=', $since)
                ->select('drama_id', DB::raw('COUNT(*) as c'))->groupBy('drama_id')
                ->orderByDesc('c')->limit($limit)->pluck('c', 'drama_id')->all();
            // Keep only published dramas, ordered by period views.
            $ids = $published()->whereIn('id', array_keys($counts))->pluck('id')->all();
            usort($ids, fn ($a, $b) => ($counts[$b] ?? 0) <=> ($counts[$a] ?? 0));
            if (count($ids) < $limit) {
                $ids = array_merge($ids, $published()->whereNotIn('id', $ids)->orderByDesc('views')
                    ->limit($limit - count($ids))->pluck('id')->all());
            }

            $out = [];
            foreach ($ids as $id) {
                $out[$id] = (int) ($counts[$id] ?? 0);
            }

            return $out;
        }

        if ($type === 'new') {
            $ids = $published()->where('release_date', '>=', now()->subDays(60)->toDateString())
                ->orderByDesc('views')->limit($limit)->pluck('id')->all();
            if (count($ids) < $limit) {
                $ids = array_merge($ids, $published()->whereNotIn('id', $ids)
                    ->orderByDesc('release_date')->limit($limit - count($ids))->pluck('id')->all());
            }
        } else {
            $ids = $published()->orderByDesc('views')->limit($limit)->pluck('id')->all();
        }

        return array_fill_keys($ids, null);
    }

    /**
     * @param  list<array<string,mixed>>  $dramas
     * @param  array<int,int|null>  $ranked
     * @return list<array<string,mixed>>
     */
    protected function withRank(array $dramas, array $ranked): array
    {
        foreach ($dramas as $i => &$drama) {
            $drama['rank'] = $i + 1;
            if (($ranked[$drama['id']] ?? null) !== null) {
                $drama['period_views'] = $ranked[$drama['id']];
            }
        }

        return $dramas;
    }

    public function show(string $slug): JsonResponse
    {
        // Drama, episode list and related rows are shared by every viewer; only is_favorite / is_unlocked
        // are per viewer and are applied after the cache read.
        $page = CatalogCache::remember('drama:'.md5($slug), function () use ($slug) {
            $drama = $this->base()->where('slug', $slug)->firstOrFail();
            $episodes = $drama->episodes()->get();
            $episodes->each->setRelation('drama', $drama);

            $catIds = $drama->categories->pluck('id');
            $related = $this->base()->where('id', '!=', $drama->id)
                ->whereHas('categories', fn ($q) => $q->whereIn('categories.id', $catIds))
                ->orderByDesc('views')->limit(12)->get();
            if ($related->count() < 6) {
                $related = $related->concat($this->base()->where('id', '!=', $drama->id)->whereNotIn('id', $related->pluck('id'))
                    ->orderByDesc('views')->limit(12 - $related->count())->get());
            }

            return [
                'drama' => $this->toArrays([$drama])[0],
                'episodes' => json_decode(json_encode(EpisodeResource::collection($episodes)->resolve()), true),
                'related' => $this->toArrays($related),
            ];
        });

        $data = $this->withFavorites([$page['drama']])[0];
        $user = Viewer::user();
        $access = app(EpisodeAccessService::class);
        $data['episodes'] = array_map(fn (array $ep) => array_merge($ep, [
            'is_unlocked' => $access->canWatchId($user, (int) $ep['drama_id'], (int) $ep['id'], (bool) $ep['is_free']),
        ]), $page['episodes']);
        $data['related'] = $this->withFavorites($page['related']);

        return $this->ok($data);
    }

    public function feed(Request $request): JsonResponse
    {
        $limit = $this->perPage(20, 50);
        $page = max(1, (int) $request->query('page', 1));

        $dramas = $this->base()->with(['episodes' => fn ($q) => $q->where('number', 1)])
            ->whereHas('episodes', fn ($q) => $q->where('number', 1))
            ->orderByDesc('views')->get();

        // Stable shuffle per day so pagination is consistent; seed param allows a client-side reshuffle.
        $seed = (int) $request->query('seed', (int) now()->format('Ymd'));
        $items = $dramas->sortBy(fn (Drama $d) => crc32($seed.'-'.$d->id))->values();
        $total = $items->count();
        $slice = $items->slice(($page - 1) * $limit, $limit)->values();

        $data = $slice->map(function (Drama $drama) {
            $ep = $drama->episodes->first();
            $ep->setRelation('drama', $drama);

            return [
                'drama' => new DramaResource($drama),
                'episode' => (new EpisodeResource($ep))->withVideo($ep->isFree()),
            ];
        });

        return $this->ok($data, [
            'current_page' => $page,
            'last_page' => max(1, (int) ceil($total / $limit)),
            'per_page' => $limit,
            'total' => $total,
            'seed' => $seed,
        ]);
    }

    public function plans(): JsonResponse
    {
        return $this->ok(CatalogCache::remember('plans', fn () => json_decode(json_encode(PlanResource::collection(
            Plan::where('is_active', true)->orderBy('sort_order')->orderBy('price')->get()
        )->resolve()), true)));
    }

    public function paymentMethods(): JsonResponse
    {
        $methods = CatalogCache::remember('payment_methods', fn () => json_decode(json_encode(PaymentMethodResource::collection(
            PaymentMethod::where('is_enabled', true)->orderBy('sort_order')->get()
        )->resolve()), true));

        return $this->ok($methods, ['groups' => array_map(
            fn (string $type) => ['type' => $type, 'label' => __('catalog.payment_groups.'.$type)],
            ['mobile_money', 'card', 'bank'],
        )]);
    }
}
