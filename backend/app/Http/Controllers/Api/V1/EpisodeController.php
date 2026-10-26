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
use App\Services\AnalyticsService;
use App\Services\CoinLedger;
use App\Services\EarningsService;
use App\Services\EpisodeAccessService;
use App\Support\VideoUrl;
use App\Support\Viewer;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class EpisodeController extends Controller
{
    public function __construct(
        protected EpisodeAccessService $access,
        protected EarningsService $earnings,
        protected CoinLedger $coins,
        protected AnalyticsService $analytics,
    ) {}

    /** Viewers only reach approved episodes of live series; staff and the owning creator can preview anything. */
    protected function findEpisode(int $id): Episode
    {
        $episode = Episode::with('drama.company')->findOrFail($id);
        if (! $episode->drama->isLive() || ! $episode->isApproved()) {
            $user = Viewer::user();
            $canPreview = $user && ($user->isSuperAdmin() || ($user->isCompany() && $user->company_id === $episode->drama->company_id));
            if (! $canPreview) {
                throw new ApiException('Hakipatikani.', 'not_found', 404);
            }
        }

        return $episode;
    }

    /** @return array<string,mixed> */
    protected function lockedPayload(Episode $episode, ?User $user): array
    {
        $drama = $episode->drama;
        $pack = $user?->activeEpisodePack();

        return [
            'episode_id' => $episode->id,
            'coins_required' => $drama->access_mode === 'vip_only' ? 0 : (int) $drama->coins_per_episode,
            'user_coins' => (int) ($user?->coins ?? 0),
            'can_use_coins' => $drama->access_mode !== 'vip_only',
            'can_use_pack' => $drama->access_mode !== 'vip_only' && (bool) $pack,
            'can_use_vip' => $drama->access_mode !== 'coins_only',
            'vip_only' => $drama->access_mode === 'vip_only',
            'episodes_remaining' => (int) ($pack?->episodes_remaining ?? 0),
            'requires_login' => $user === null,
        ];
    }

    /** GET /episodes/{id}/play, auth optional. */
    public function play(int $id): JsonResponse
    {
        $episode = $this->findEpisode($id);
        $drama = $episode->drama;
        $user = Viewer::user();

        if (! $this->access->canWatch($user, $episode)) {
            $message = match (true) {
                $user === null => 'Episode hii imefungwa. Ingia kisha ujiunge na VIP au uifungue kwa coins.',
                $drama->access_mode === 'vip_only' => 'Episode hii ni ya wanachama wa VIP pekee.',
                $drama->access_mode === 'coins_only' => 'Episode hii imefungwa. Ifungue kwa coins au kifurushi cha episodes.',
                default => 'Episode hii imefungwa. Jiunge na VIP au uifungue kwa coins.',
            };
            throw new ApiException($message, 'episode_locked', 402, ['unlock' => $this->lockedPayload($episode, $user)]);
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

        });

        // Resume where the viewer left off in this episode; starting a different episode does not wipe that progress.
        $resume = 0;
        if ($user) {
            $history = WatchHistory::where('user_id', $user->id)->where('drama_id', $drama->id)->first();
            if ($history && (int) $history->episode_id === $episode->id) {
                $resume = (int) $history->progress_seconds;
            } else {
                WatchHistory::updateOrCreate(
                    ['user_id' => $user->id, 'drama_id' => $drama->id],
                    ['episode_id' => $episode->id, 'progress_seconds' => 0],
                );
            }
        }
        $duration = (int) $episode->duration_seconds;
        if ($duration > 0 && $resume >= $duration - 5) {
            $resume = 0;
        }
        $this->analytics->markActive($user, request());

        $prev = Episode::where('drama_id', $drama->id)->approved()->where('number', '<', $episode->number)->orderByDesc('number')->value('id');
        $next = Episode::where('drama_id', $drama->id)->approved()->where('number', '>', $episode->number)->orderBy('number')->value('id');

        return $this->ok([
            'video_url' => VideoUrl::primary($episode),
            'sources' => VideoUrl::sources($episode),
            'subtitle_url' => $episode->subtitle_url,
            'resume_seconds' => $resume,
            // Send back with POST /events so watch time, completion and errors are tied to this playback.
            'session_id' => (string) Str::uuid(),
            'episode' => (new EpisodeResource($episode))->withVideo(),
            'drama' => ['id' => $drama->id, 'slug' => $drama->slug, 'title' => $drama->title, 'total_episodes' => (int) $drama->total_episodes,
                'free_episodes' => (int) $drama->free_episodes, 'poster_url' => $drama->poster_url],
            'next_episode_id' => $next,
            'prev_episode_id' => $prev,
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

        if ($drama->access_mode === 'vip_only') {
            throw new ApiException('Episode hii ni ya wanachama wa VIP pekee; haiwezi kufunguliwa kwa coins.', 'vip_required', 402,
                ['unlock' => $this->lockedPayload($episode, $user)]);
        }

        DB::transaction(function () use ($episode, $drama, $user, $method) {
            $user = User::whereKey($user->id)->lockForUpdate()->first();

            if ($method === 'coins') {
                $cost = (int) $drama->coins_per_episode;
                if ($user->coins < $cost) {
                    throw new ApiException('Huna coins za kutosha kufungua episode hii.', 'insufficient_coins', 402,
                        ['unlock' => $this->lockedPayload($episode, $user)]);
                }
                $this->coins->debit($user, $cost, 'unlock', ['episode_id' => $episode->id], "{$drama->title} · Episode {$episode->number}");
                EpisodeUnlock::create([
                    'user_id' => $user->id, 'episode_id' => $episode->id, 'method' => 'coins', 'coins_spent' => $cost,
                ]);
                $this->earnings->recordCoinUnlock($episode, $cost, $user->id);
            } else {
                $pack = $user->activeEpisodePack();
                if (! $pack) {
                    throw new ApiException('Huna kifurushi cha episodes kinachotumika.', 'no_episode_pack', 402,
                        ['unlock' => $this->lockedPayload($episode, $user)]);
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
