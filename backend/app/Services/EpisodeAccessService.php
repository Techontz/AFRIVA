<?php

namespace App\Services;

use App\Models\Episode;
use App\Models\EpisodeUnlock;
use App\Models\User;
use App\Support\Viewer;

class EpisodeAccessService
{
    public function hasTimeSubscription(?User $user): bool
    {
        if (! $user) {
            return false;
        }

        return Viewer::remember('access.time_sub.'.$user->id, fn () => $user->activeTimeSubscription() !== null);
    }

    /** @return array<int,bool> episode_id => true for the given drama */
    public function unlockedEpisodeIds(?User $user, int $dramaId): array
    {
        if (! $user) {
            return [];
        }

        return Viewer::remember("access.unlocks.{$user->id}.{$dramaId}", function () use ($user, $dramaId) {
            $ids = EpisodeUnlock::query()
                ->where('user_id', $user->id)
                ->whereIn('episode_id', fn ($q) => $q->select('id')->from('episodes')->where('drama_id', $dramaId))
                ->pluck('episode_id')
                ->all();

            return array_fill_keys($ids, true);
        });
    }

    public function canWatch(?User $user, Episode $episode): bool
    {
        if ($episode->isFree()) {
            return true;
        }

        return $this->canWatchId($user, (int) $episode->drama_id, (int) $episode->id, false);
    }

    /** Same rule as canWatch() for callers that only hold ids (e.g. cached episode lists). */
    public function canWatchId(?User $user, int $dramaId, int $episodeId, bool $isFree): bool
    {
        if ($isFree) {
            return true;
        }
        if (! $user) {
            return false;
        }
        if ($this->hasTimeSubscription($user)) {
            return true;
        }

        return isset($this->unlockedEpisodeIds($user, $dramaId)[$episodeId]);
    }

    public function flush(?User $user, int $dramaId): void
    {
        if ($user) {
            Viewer::forget('access.time_sub.'.$user->id);
            Viewer::forget("access.unlocks.{$user->id}.{$dramaId}");
        }
    }
}
