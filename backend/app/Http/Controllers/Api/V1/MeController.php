<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\CoinTransactionResource;
use App\Http\Resources\DramaResource;
use App\Http\Resources\HistoryResource;
use App\Http\Resources\PaymentResource;
use App\Http\Resources\SubscriptionResource;
use App\Models\Drama;
use App\Support\Viewer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MeController extends Controller
{
    /** GET /me/subscription → data: active subscription (time-based preferred, else episode pack) or null. */
    public function subscription(Request $request): JsonResponse
    {
        $user = $request->user();
        $active = $user->activeSubscription();
        $pack = $user->activeEpisodePack();

        return $this->ok($active ? new SubscriptionResource($active) : null, [
            'is_vip' => $user->activeTimeSubscription() !== null,
            'coins' => (int) $user->coins,
            'episodes_remaining' => (int) $user->subscriptions()->where('type', 'episodes')->where('status', 'active')->sum('episodes_remaining'),
            'episode_pack' => $pack ? new SubscriptionResource($pack) : null,
            'history' => SubscriptionResource::collection($user->subscriptions()->with('plan')->latest()->limit(20)->get()),
        ]);
    }

    public function payments(Request $request): JsonResponse
    {
        $p = $request->user()->payments()->with('plan')->latest()->paginate($this->perPage(20));

        return $this->paginated($p, PaymentResource::class);
    }

    /** GET /me/coins: coin balance and ledger (purchases, bonuses, unlocks, refunds). */
    public function coins(Request $request): JsonResponse
    {
        $p = $request->user()->coinTransactions()->with('episode.drama')->latest('id')->paginate($this->perPage(30));

        return $this->paginated($p, CoinTransactionResource::class, ['balance' => (int) $request->user()->coins]);
    }

    public function history(Request $request): JsonResponse
    {
        $p = $request->user()->watchHistories()
            ->with(['drama.categories', 'drama.tags', 'drama.company', 'episode.drama'])
            ->whereHas('drama')
            ->latest('updated_at')->paginate($this->perPage(30));

        return $this->paginated($p, HistoryResource::class);
    }

    public function favorites(Request $request): JsonResponse
    {
        $p = $request->user()->favorites()->with(['categories', 'tags', 'company'])
            ->orderByPivot('created_at', 'desc')->paginate($this->perPage(30));

        return $this->paginated($p, DramaResource::class);
    }

    /** POST /me/favorites/{drama_id}, toggle. */
    public function toggleFavorite(Request $request, int $dramaId): JsonResponse
    {
        $drama = Drama::findOrFail($dramaId);
        $result = $request->user()->favorites()->toggle([$drama->id]);
        $isFavorite = ! empty($result['attached']);
        Viewer::forget('viewer.favorites');

        return $this->ok(['drama_id' => $drama->id, 'is_favorite' => $isFavorite]);
    }
}
