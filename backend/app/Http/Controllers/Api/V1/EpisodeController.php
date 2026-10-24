<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\ProgressRequest;
use App\Http\Requests\UnlockEpisodeRequest;
use App\Http\Resources\EpisodeResource;
use App\Models\Episode;
use App\Models\EpisodeUnlock;
use App\Models\EpisodeView;
use App\Models\User;
use App\Models\WatchHistory;
use App\Services\EarningsService;
use App\Services\EpisodeAccessService;
use App\Support\Viewer;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class EpisodeController extends Controller
{
    public function __construct(
        protected EpisodeAccessService $access,
        protected EarningsService $earnings,
    ) {}

    protected function findEpisode(int $id): Episode
    {
        $episode = Episode::with('drama.company')->findOrFail($id);
        if ($episode->drama->status !== 'published') {
            $user = Viewer::user();
            $canPreview = $user && ($user->isSuperAdmin() || ($user->isCompany() && $user->company_id === $episode->drama->company_id));
            if (! $canPreview) {
                throw new ApiException('Resource not found.', 'not_found', 404);
            }
        }

        return $episode;
    }

    /** GET /episodes/{id}/play — auth optional. */
    public function play(int $id): JsonResponse
    {
        $episode = $this->findEpisode($id);
        $drama = $episode->drama;
        $user = Viewer::user();

        if (! $this->access->canWatch($user, $episode)) {
            throw new ApiException(
                $user ? 'This episode is locked. Subscribe to VIP or unlock it with coins.' : 'This episode is locked. Log in and subscribe or unlock it with coins.',
                'episode_locked',
                402,
                ['unlock' => [
                    'episode_id' => $episode->id,
                    'coins_required' => (int) $drama->coins_per_episode,
                    'user_coins' => (int) ($user?->coins ?? 0),
                    'can_use_pack' => (bool) $user?->activeEpisodePack(),
                    'episodes_remaining' => (int) ($user?->activeEpisodePack()?->episodes_remaining ?? 0),
                    'requires_login' => $user === null,
                ]]
            );
        }

        DB::transaction(function () use ($episode, $drama, $user) {
            EpisodeView::create([
                'episode_id' => $episode->id,
                'drama_id' => $drama->id,
                'company_id' => $drama->company_id,
                'user_id' => $user?->id,
                'viewed_on' => now()->toDateString(),
            ]);
            Episode::whereKey($episode->id)->increment('views');
            $drama->newQuery()->whereKey($drama->id)->increment('views');

            if ($user) {
                WatchHistory::updateOrCreate(
                    ['user_id' => $user->id, 'drama_id' => $drama->id],
                    ['episode_id' => $episode->id, 'progress_seconds' => 0],
                );
            }
        });

        $siblings = Episode::where('drama_id', $drama->id)
            ->whereIn('number', [$episode->number - 1, $episode->number + 1])
            ->pluck('id', 'number');

        return $this->ok([
            'video_url' => $episode->video_url,
            'episode' => (new EpisodeResource($episode))->withVideo(),
            'drama' => ['id' => $drama->id, 'slug' => $drama->slug, 'title' => $drama->title, 'total_episodes' => (int) $drama->total_episodes, 'poster_url' => $drama->poster_url],
            'next_episode_id' => $siblings[$episode->number + 1] ?? null,
            'prev_episode_id' => $siblings[$episode->number - 1] ?? null,
        ]);
    }

    /** POST /episodes/{id}/unlock {method: coins|episode_pack} */
    public function unlock(UnlockEpisodeRequest $request, int $id): JsonResponse
    {
        $episode = $this->findEpisode($id);
        $drama = $episode->drama;
        /** @var User $user */
        $user = $request->user();
        $method = $request->input('method');

        if ($this->access->canWatch($user, $episode)) {
            return $this->ok($this->unlockPayload($episode, $user, $method, true));
        }

        DB::transaction(function () use ($episode, $drama, $user, $method) {
            $user = User::whereKey($user->id)->lockForUpdate()->first();

            if ($method === 'coins') {
                $cost = (int) $drama->coins_per_episode;
                if ($user->coins < $cost) {
                    throw new ApiException('Not enough coins to unlock this episode.', 'insufficient_coins', 402, ['unlock' => [
                        'episode_id' => $episode->id,
                        'coins_required' => $cost,
                        'user_coins' => (int) $user->coins,
                        'can_use_pack' => (bool) $user->activeEpisodePack(),
                    ]]);
                }
                $user->decrement('coins', $cost);
                EpisodeUnlock::create([
                    'user_id' => $user->id, 'episode_id' => $episode->id, 'method' => 'coins', 'coins_spent' => $cost,
                ]);
                $this->earnings->recordCoinUnlock($episode, $cost, $user->id);
            } else {
                $pack = $user->activeEpisodePack();
                if (! $pack) {
                    throw new ApiException('You have no active episode pack.', 'no_episode_pack', 402, ['unlock' => [
                        'episode_id' => $episode->id,
                        'coins_required' => (int) $drama->coins_per_episode,
                        'user_coins' => (int) $user->coins,
                        'can_use_pack' => false,
                    ]]);
                }
                $pack->episodes_remaining = $pack->episodes_remaining - 1;
                if ($pack->episodes_remaining <= 0) {
                    $pack->status = 'expired';
                }
                $pack->save();
                EpisodeUnlock::create([
                    'user_id' => $user->id, 'episode_id' => $episode->id, 'method' => 'episode_pack',
                    'coins_spent' => 0, 'subscription_id' => $pack->id,
                ]);
                $this->earnings->recordPackUnlock($episode, $pack, $user->id);
            }
        });

        $this->access->flush($user, $drama->id);
        $user->refresh();

        return $this->ok($this->unlockPayload($episode, $user, $method, false));
    }

    protected function unlockPayload(Episode $episode, User $user, string $method, bool $already): array
    {
        $pack = $user->activeEpisodePack();

        return [
            'unlocked' => true,
            'already_unlocked' => $already,
            'method' => $method,
            'episode' => (new EpisodeResource($episode))->withVideo(),
            'user_coins' => (int) $user->coins,
            'episodes_remaining' => (int) ($pack?->episodes_remaining ?? 0),
        ];
    }

    /** POST /episodes/{id}/progress {progress_seconds} */
    public function progress(ProgressRequest $request, int $id): JsonResponse
    {
        $episode = $this->findEpisode($id);
        $history = WatchHistory::updateOrCreate(
            ['user_id' => $request->user()->id, 'drama_id' => $episode->drama_id],
            ['episode_id' => $episode->id, 'progress_seconds' => (int) $request->input('progress_seconds')],
        );

        return $this->ok([
            'drama_id' => $history->drama_id,
            'episode_id' => $history->episode_id,
            'progress_seconds' => (int) $history->progress_seconds,
        ]);
    }
}
