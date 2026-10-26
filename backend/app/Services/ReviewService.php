<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\AuditLog;
use App\Models\ContentReview;
use App\Models\Drama;
use App\Models\Episode;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Creator → admin content workflow (scope §04):
 * Tuma kazi (submit) → Kagua (review) → Rekebisha (changes requested, resubmit) → Chapisha (approve, then publish with rules).
 * Uploading never publishes anything: a series is only live once approved AND published by staff.
 */
class ReviewService
{
    /**
     * Creator sends a series (with its draft episodes), or new episodes of an approved series, for review.
     */
    public function submit(Drama $drama, User $creator, bool $rightsDeclared): Drama
    {
        $company = $drama->company;
        if (! $company?->isActive()) {
            throw new ApiException('Akaunti yako ya mtayarishaji bado haijaidhinishwa. Utaweza kutuma kazi baada ya AFRIVA kuiidhinisha.', 'creator_not_approved', 403);
        }
        if (! $company->hasAcceptedAgreement()) {
            throw new ApiException('Kubali mkataba wa mapato wa watayarishaji kabla ya kutuma kazi.', 'agreement_required', 403);
        }
        if (! $rightsDeclared) {
            throw ValidationException::withMessages(['rights_declaration' => ['Thibitisha kuwa una haki zote za maudhui haya.']]);
        }
        if (in_array($drama->review_status, Drama::REVIEW_PENDING, true)) {
            throw new ApiException('Kazi hii tayari imetumwa na inasubiri ukaguzi.', 'already_submitted', 409);
        }
        if ($drama->review_status === Drama::REVIEW_REJECTED) {
            throw new ApiException('Series hii imekataliwa na haiwezi kutumwa tena.', 'rejected', 409);
        }

        $pendingEpisodes = $drama->episodes()->whereIn('review_status', Drama::CREATOR_EDITABLE)->get();
        $seriesUnderReview = $drama->review_status !== Drama::REVIEW_APPROVED;

        $errors = [];
        if ($seriesUnderReview) {
            if (! trim((string) $drama->synopsis)) {
                $errors['synopsis'] = ['Andika maelezo ya series.'];
            }
            if (! $drama->poster_url) {
                $errors['poster'] = ['Weka cover (poster) ya series.'];
            }
            if ($drama->categories()->count() === 0) {
                $errors['category_ids'] = ['Chagua angalau genre moja.'];
            }
        }
        if ($pendingEpisodes->isEmpty()) {
            $errors['episodes'] = ['Ongeza angalau episode moja kabla ya kutuma.'];
        }
        $missingVideo = $pendingEpisodes->filter(fn (Episode $e) => ! $e->video_url)->pluck('number');
        if ($missingVideo->isNotEmpty()) {
            $errors['episodes'] = ['Episode hizi hazina video: '.$missingVideo->implode(', ').'.'];
        }
        if ($errors) {
            throw ValidationException::withMessages($errors);
        }

        DB::transaction(function () use ($drama, $creator, $pendingEpisodes, $seriesUnderReview) {
            $from = $drama->review_status;
            $action = $from === Drama::REVIEW_CHANGES ? 'resubmitted' : 'submitted';
            if ($seriesUnderReview) {
                $drama->forceFill([
                    'review_status' => Drama::REVIEW_SUBMITTED,
                    'submitted_at' => now(),
                    'rights_declared_at' => now(),
                ])->save();
            } else {
                $drama->forceFill(['submitted_at' => now(), 'rights_declared_at' => now()])->save();
            }
            foreach ($pendingEpisodes as $episode) {
                $episode->forceFill(['review_status' => Drama::REVIEW_SUBMITTED])->save();
            }

            $this->log($drama, null, $creator, $action, $from, $seriesUnderReview ? Drama::REVIEW_SUBMITTED : $from,
                $seriesUnderReview ? null : 'Episode mpya: '.$pendingEpisodes->pluck('number')->implode(', '));
        });

        return $drama->fresh();
    }

    /** Reviewer picks up a submission (Imetumwa → Inakaguliwa). */
    public function startReview(Drama $drama, User $reviewer): Drama
    {
        $episodes = $drama->episodes()->where('review_status', Drama::REVIEW_SUBMITTED)->get();
        if ($drama->review_status !== Drama::REVIEW_SUBMITTED && $episodes->isEmpty()) {
            throw new ApiException('Hakuna kazi iliyotumwa inayosubiri kukaguliwa kwenye series hii.', 'nothing_to_review', 409);
        }

        DB::transaction(function () use ($drama, $reviewer, $episodes) {
            if ($drama->review_status === Drama::REVIEW_SUBMITTED) {
                $drama->forceFill(['review_status' => Drama::REVIEW_IN_REVIEW, 'reviewed_by' => $reviewer->id])->save();
            }
            foreach ($episodes as $episode) {
                $episode->forceFill(['review_status' => Drama::REVIEW_IN_REVIEW])->save();
            }
            $this->log($drama, null, $reviewer, 'review_started', Drama::REVIEW_SUBMITTED, Drama::REVIEW_IN_REVIEW);
        });

        return $drama->fresh();
    }

    /** Reviewer confirms an episode's video plays correctly ("ipimwe playback"). */
    public function verifyPlayback(Episode $episode, User $reviewer): Episode
    {
        if (! $episode->video_url) {
            throw new ApiException('Episode hii haina video.', 'no_video', 422);
        }
        if ($episode->video_status !== 'ready') {
            throw new ApiException('Video bado inachakatwa au imeshindikana. Subiri iwe tayari kabla ya kuipima.', 'video_not_ready', 422);
        }
        $episode->forceFill(['playback_verified_at' => now()])->save();
        $this->log($episode->drama, $episode, $reviewer, 'playback_verified', null, null);

        return $episode;
    }

    /**
     * approve | request_changes | reject the pending parts of a series. Optionally limited to some episodes.
     *
     * @param  list<int>|null  $episodeIds
     */
    public function decide(Drama $drama, User $reviewer, string $decision, ?string $notes, ?array $episodeIds = null): Drama
    {
        $target = [
            'approve' => Drama::REVIEW_APPROVED,
            'request_changes' => Drama::REVIEW_CHANGES,
            'reject' => Drama::REVIEW_REJECTED,
        ][$decision] ?? null;
        if (! $target) {
            throw ValidationException::withMessages(['decision' => ['Uamuzi si sahihi.']]);
        }
        if ($decision !== 'approve' && ! trim((string) $notes)) {
            throw ValidationException::withMessages(['notes' => ['Andika maoni kwa mtayarishaji.']]);
        }

        $seriesPending = in_array($drama->review_status, Drama::REVIEW_PENDING, true);
        /** @var Collection<int,Episode> $episodes */
        $episodes = $drama->episodes()->whereIn('review_status', Drama::REVIEW_PENDING)
            ->when($episodeIds !== null, fn ($q) => $q->whereIn('id', $episodeIds))->get();

        if (! $seriesPending && $episodes->isEmpty()) {
            throw new ApiException('Hakuna kazi inayosubiri uamuzi kwenye series hii.', 'nothing_to_review', 409);
        }

        if ($decision === 'approve') {
            $notReady = $episodes->filter(fn (Episode $e) => $e->video_status !== 'ready' || ! $e->playback_verified_at)->pluck('number');
            if ($notReady->isNotEmpty()) {
                throw ValidationException::withMessages(['episodes' => [
                    'Pima playback ya episode hizi kabla ya kuidhinisha: '.$notReady->implode(', ').'.',
                ]]);
            }
            if ($seriesPending && $episodes->isEmpty() && $drama->episodes()->approved()->count() === 0) {
                throw ValidationException::withMessages(['episodes' => ['Series inahitaji angalau episode moja iliyoidhinishwa.']]);
            }
        }

        DB::transaction(function () use ($drama, $reviewer, $decision, $notes, $target, $seriesPending, $episodes) {
            if ($seriesPending) {
                $from = $drama->review_status;
                $drama->forceFill([
                    'review_status' => $target,
                    'review_notes' => $notes,
                    'reviewed_at' => now(),
                    'reviewed_by' => $reviewer->id,
                ])->save();
                $this->log($drama, null, $reviewer, $decision, $from, $target, $notes);
            }
            foreach ($episodes as $episode) {
                $from = $episode->review_status;
                $episode->forceFill(['review_status' => $target, 'review_notes' => $notes])->save();
                $this->log($drama, $episode, $reviewer, $decision, $from, $target, $seriesPending ? null : $notes);
            }
            $drama->refreshEpisodeCount();

            AuditLog::record("review.{$decision}", $drama, [
                'episodes' => $episodes->pluck('number')->all(),
                'series' => $seriesPending,
            ], "{$drama->title}: {$decision}".($notes ? " ({$notes})" : ''));
        });

        return $drama->fresh();
    }

    /**
     * Staff publishes an approved series with its publishing rules (scope §05 "Publishing rules").
     *
     * @param  array{publish_at?:string|null,free_episodes?:int,coins_per_episode?:int,access_mode?:string,is_featured?:bool,badge?:string|null}  $rules
     */
    public function publish(Drama $drama, User $staff, array $rules): Drama
    {
        if ($drama->review_status !== Drama::REVIEW_APPROVED) {
            throw new ApiException('Series lazima iidhinishwe na mkaguzi kabla ya kuchapishwa.', 'not_approved', 422);
        }
        if ($drama->episodes()->approved()->count() === 0) {
            throw new ApiException('Series haina episode iliyoidhinishwa.', 'no_episodes', 422);
        }

        DB::transaction(function () use ($drama, $staff, $rules) {
            $before = $drama->only(['status', 'publish_at', 'free_episodes', 'coins_per_episode', 'access_mode']);
            $drama->fill(collect($rules)->only(['free_episodes', 'coins_per_episode', 'access_mode', 'is_featured', 'badge'])->all());
            $drama->publish_at = ! empty($rules['publish_at']) ? $rules['publish_at'] : null;
            $drama->status = 'published';
            $drama->release_date ??= ($drama->publish_at ?? now())->toDateString();
            $drama->save();

            $this->log($drama, null, $staff, $drama->isScheduled() ? 'scheduled' : 'published', null, null,
                $drama->isScheduled() ? 'Itachapishwa '.$drama->publish_at->toDateTimeString() : null);
            AuditLog::record('drama.publish', $drama, [
                'before' => $before,
                'after' => $drama->only(['status', 'publish_at', 'free_episodes', 'coins_per_episode', 'access_mode']),
            ], $drama->title);
        });

        return $drama->fresh();
    }

    public function unpublish(Drama $drama, User $staff): Drama
    {
        $drama->forceFill(['status' => 'draft'])->save();
        $this->log($drama, null, $staff, 'unpublished', null, null);
        AuditLog::record('drama.unpublish', $drama, null, $drama->title);

        return $drama->fresh();
    }

    protected function log(Drama $drama, ?Episode $episode, User $user, string $action, ?string $from, ?string $to, ?string $notes = null): void
    {
        ContentReview::create([
            'drama_id' => $drama->id,
            'episode_id' => $episode?->id,
            'user_id' => $user->id,
            'action' => $action,
            'from_status' => $from,
            'to_status' => $to,
            'notes' => $notes,
        ]);
    }
}
