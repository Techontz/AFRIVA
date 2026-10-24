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
use App\Models\Plan;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Public catalogue: home, categories, dramas, rankings, detail, feed, plans, payment methods.
 */
class CatalogController extends Controller
{
    protected function base(): Builder
    {
        return Drama::query()->published()->with(['categories', 'tags', 'company']);
    }

    public function home(): JsonResponse
    {
        $banners = $this->base()->where('is_featured', true)->orderByDesc('views')->limit(6)->get();
        if ($banners->isEmpty()) {
            $banners = $this->base()->orderByDesc('views')->limit(5)->get();
        }

        $sections = [
            ['key' => 'must_watch', 'title' => 'Must-Watch', 'layout' => 'row',
                'dramas' => $this->base()->where(fn ($q) => $q->where('badge', 'hot')->orWhere('is_featured', true))->orderByDesc('views')->limit(12)->get()],
            ['key' => 'trending', 'title' => 'Trending Now', 'layout' => 'ranking',
                'dramas' => $this->ranked('trending', 10)],
            ['key' => 'new_releases', 'title' => 'New Releases', 'layout' => 'row',
                'dramas' => $this->base()->orderByDesc('release_date')->orderByDesc('id')->limit(12)->get()],
            ['key' => 'hidden_gems', 'title' => 'Hidden Gems', 'layout' => 'row',
                'dramas' => $this->base()->orderBy('views')->limit(12)->get()],
        ];

        foreach (['romance' => 'Romance', 'revenge' => 'Revenge', 'billionaire' => 'Billionaire', 'family' => 'Family Drama', 'village-life' => 'Village Life'] as $slug => $title) {
            $dramas = $this->base()->whereHas('categories', fn ($q) => $q->where('slug', $slug))->orderByDesc('views')->limit(12)->get();
            if ($dramas->isNotEmpty()) {
                $sections[] = ['key' => str_replace('-', '_', $slug), 'title' => $title, 'layout' => 'row', 'dramas' => $dramas, 'category' => $slug];
            }
        }

        $sections[] = ['key' => 'popular', 'title' => 'Popular on Afriva', 'layout' => 'grid',
            'dramas' => $this->base()->orderByDesc('views')->limit(18)->get()];

        return $this->ok([
            'banners' => DramaResource::collection($banners),
            'sections' => array_map(fn ($s) => array_merge($s, ['dramas' => DramaResource::collection($s['dramas'])]), $sections),
        ]);
    }

    public function categories(): JsonResponse
    {
        return $this->ok(CategoryResource::collection(
            Category::withCount(['dramas' => fn ($q) => $q->where('status', 'published')])->orderBy('sort_order')->orderBy('name')->get()
        ));
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

        return $this->ok(DramaResource::collection($this->ranked($type, $limit)), ['type' => $type]);
    }

    /** trending = most views in the last 7 days; new = most viewed released in the last 60 days; popular = all-time views. */
    protected function ranked(string $type, int $limit): Collection
    {
        if ($type === 'trending') {
            $since = now()->subDays(6)->toDateString();
            $counts = DB::table('episode_views')->where('viewed_on', '>=', $since)
                ->select('drama_id', DB::raw('COUNT(*) as c'))->groupBy('drama_id')
                ->orderByDesc('c')->limit($limit)->pluck('c', 'drama_id')->all();
            $dramas = $this->base()->whereIn('id', array_keys($counts))->get()
                ->sortByDesc(fn ($d) => $counts[$d->id] ?? 0)->values();
            if ($dramas->count() < $limit) {
                $more = $this->base()->whereNotIn('id', $dramas->pluck('id'))->orderByDesc('views')->limit($limit - $dramas->count())->get();
                $dramas = $dramas->concat($more);
            }
            $dramas->each(fn ($d) => $d->setAttribute('period_views', $counts[$d->id] ?? 0));
        } elseif ($type === 'new') {
            $dramas = $this->base()->where('release_date', '>=', now()->subDays(60)->toDateString())
                ->orderByDesc('views')->limit($limit)->get();
            if ($dramas->count() < $limit) {
                $dramas = $dramas->concat($this->base()->whereNotIn('id', $dramas->pluck('id'))
                    ->orderByDesc('release_date')->limit($limit - $dramas->count())->get());
            }
        } else {
            $dramas = $this->base()->orderByDesc('views')->limit($limit)->get();
        }

        $dramas = new Collection($dramas->values()->all());
        $dramas->each(fn ($d, $i) => $d->setAttribute('rank', $i + 1));

        return $dramas;
    }

    public function show(string $slug): JsonResponse
    {
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

        $data = (new DramaResource($drama))->resolve();
        $data['episodes'] = EpisodeResource::collection($episodes);
        $data['related'] = DramaResource::collection($related);

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
        return $this->ok(PlanResource::collection(Plan::where('is_active', true)->orderBy('sort_order')->orderBy('price')->get()));
    }

    public function paymentMethods(): JsonResponse
    {
        return $this->ok(
            PaymentMethodResource::collection(PaymentMethod::where('is_enabled', true)->orderBy('sort_order')->get()),
            ['groups' => [
                ['type' => 'mobile_money', 'label' => 'Mobile Money'],
                ['type' => 'card', 'label' => 'Cards'],
                ['type' => 'bank', 'label' => 'Bank'],
            ]]
        );
    }
}
