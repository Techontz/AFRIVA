<?php

namespace App\Services;

use App\Models\Drama;
use App\Models\Episode;
use App\Models\OperatingCost;
use App\Models\Setting;
use App\Models\User;
use App\Models\WatchSession;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Analytics (scope §06): every number comes from real rows: payments, refunds, the coin ledger,
 * episode views, player events (watch_sessions) and daily active users. Nothing is estimated except
 * the streaming cost, which is labelled as an estimate unless finance has entered the real cost.
 */
class AnalyticsService
{
    /** Longest watch time a single event may add (guards against bogus clients). */
    protected const MAX_EVENT_SECONDS = 120;

    public function actorKey(?User $user, Request $request): string
    {
        if ($user) {
            return 'u:'.$user->id;
        }
        $device = (string) $request->header('X-Device-Id', '');
        if (preg_match('/^[A-Za-z0-9_-]{8,64}$/', $device)) {
            return 'd:'.$device;
        }

        return 'd:ip-'.substr(sha1($request->ip().'|'.$request->userAgent()), 0, 24);
    }

    /** Count this viewer as active today (DAU / MAU). */
    public function markActive(?User $user, Request $request): void
    {
        DB::table('active_users')->insertOrIgnore([
            'active_on' => now()->toDateString(),
            'actor_key' => $this->actorKey($user, $request),
            'user_id' => $user?->id,
        ]);
    }

    /**
     * Player events → watch_sessions. Event: {session_id, episode_id, type: start|heartbeat|complete|error|quality,
     * position_seconds?, watched_seconds?, duration_seconds?, quality?}.
     *
     * @param  list<array<string,mixed>>  $events
     */
    public function ingest(array $events, ?User $user, Request $request): int
    {
        $actor = $this->actorKey($user, $request);
        $device = str_starts_with($actor, 'd:') ? substr($actor, 2) : null;
        $episodes = Episode::with('drama')->whereIn('id', collect($events)->pluck('episode_id')->unique())->get()->keyBy('id');
        $accepted = 0;

        foreach ($events as $event) {
            $episode = $episodes->get((int) $event['episode_id']);
            if (! $episode || ! $episode->drama) {
                continue;
            }

            $session = WatchSession::firstOrNew(['session_key' => (string) $event['session_id']]);
            if ($session->exists && ($session->episode_id !== $episode->id || $session->actor_key !== $actor)) {
                continue;
            }
            if (! $session->exists) {
                $session->fill([
                    'user_id' => $user?->id,
                    'device_id' => $device,
                    'actor_key' => $actor,
                    'episode_id' => $episode->id,
                    'drama_id' => $episode->drama_id,
                    'company_id' => $episode->drama->company_id,
                    'watched_on' => now()->toDateString(),
                    'duration_seconds' => (int) $episode->duration_seconds,
                ]);
            }

            $type = (string) $event['type'];
            $position = max(0, (int) ($event['position_seconds'] ?? 0));
            $duration = max((int) $session->duration_seconds, (int) ($event['duration_seconds'] ?? 0));
            $session->duration_seconds = $duration;
            $session->watch_seconds = (int) $session->watch_seconds + min(self::MAX_EVENT_SECONDS, max(0, (int) ($event['watched_seconds'] ?? 0)));
            $session->max_position = max((int) $session->max_position, $duration > 0 ? min($position, $duration) : $position);
            if ($type === 'complete' || ($duration > 0 && $session->max_position >= 0.9 * $duration)) {
                $session->completed = true;
            }
            if ($type === 'error') {
                $session->errors = (int) $session->errors + 1;
            }
            if (! empty($event['quality'])) {
                $session->last_quality = substr((string) $event['quality'], 0, 10);
            }
            $session->save();
            $accepted++;
        }

        if ($accepted > 0) {
            $this->markActive($user, $request);
        }

        return $accepted;
    }

    /** @return array{0:Carbon,1:Carbon,2:string,3:string} */
    protected function range(int $days): array
    {
        $from = now()->subDays($days - 1)->startOfDay();
        $to = now()->endOfDay();

        return [$from, $to, $from->toDateString(), $to->toDateString()];
    }

    /** @return list<string> */
    protected function dates(int $days): array
    {
        $out = [];
        for ($i = $days - 1; $i >= 0; $i--) {
            $out[] = now()->subDays($i)->toDateString();
        }

        return $out;
    }

    /** @param array<string,int|float> $map */
    protected function series(array $map, int $days): array
    {
        return array_map(fn ($d) => ['date' => $d, 'value' => (int) round((float) ($map[$d] ?? 0))], $this->dates($days));
    }

    public function streamingCost(int $watchSeconds): int
    {
        $gb = $watchSeconds * (float) Setting::get('streaming_avg_kbps', 1200) * 1000 / 8 / 1e9;

        return (int) round($gb * (float) Setting::get('streaming_cost_per_gb_tzs', 230));
    }

    /**
     * Platform overview for the admin Analytics page.
     *
     * @return array<string,mixed>
     */
    public function overview(int $days = 30): array
    {
        [$from, $to, $fromDate, $toDate] = $this->range($days);

        // ---- Revenue: gross, refunds, fees, net ---------------------------------
        $paid = DB::table('payments')->whereIn('status', ['success', 'refunded'])->whereBetween('paid_at', [$from, $to]);
        $gross = (int) (clone $paid)->sum('amount');
        $fees = (int) (clone $paid)->sum('fee_amount');
        $refunds = (int) DB::table('refunds')->whereBetween('created_at', [$from, $to])->sum('amount');
        $net = $gross - $refunds - $fees;

        $watchSeconds = (int) DB::table('watch_sessions')->whereBetween('watched_on', [$fromDate, $toDate])->sum('watch_seconds');
        $costs = OperatingCost::whereBetween('period', [$from->copy()->startOfMonth()->toDateString(), $toDate])
            ->select('category', DB::raw('SUM(amount) as total'))->groupBy('category')->pluck('total', 'category')
            ->map(fn ($v) => (int) $v)->all();
        $streamingEstimate = $this->streamingCost($watchSeconds);
        $streamingActual = $costs['streaming'] ?? null;
        $streamingCost = $streamingActual ?? $streamingEstimate;
        $otherCosts = array_sum(array_diff_key($costs, ['streaming' => true]));

        $grossByDay = (clone $paid)->selectRaw('DATE(paid_at) as d, SUM(amount) as v, SUM(fee_amount) as f')->groupByRaw('DATE(paid_at)')->get()->keyBy('d');
        $refundsByDay = DB::table('refunds')->whereBetween('created_at', [$from, $to])
            ->selectRaw('DATE(created_at) as d, SUM(amount) as v')->groupByRaw('DATE(created_at)')->pluck('v', 'd');
        $revenueChart = array_map(function ($d) use ($grossByDay, $refundsByDay) {
            $g = (int) ($grossByDay[$d]->v ?? 0);

            return ['date' => $d, 'gross' => $g, 'net' => $g - (int) ($grossByDay[$d]->f ?? 0) - (int) ($refundsByDay[$d] ?? 0)];
        }, $this->dates($days));

        $planTypes = DB::table('plans')->pluck('type', 'id');
        $byType = (clone $paid)->select('plan_id', DB::raw('SUM(amount) as total'))->groupBy('plan_id')->get()
            ->groupBy(fn ($r) => $planTypes[$r->plan_id] ?? 'other')
            ->map(fn ($g, $type) => ['type' => $type, 'value' => (int) $g->sum('total')])->values();

        // ---- Viewers ----------------------------------------------------------
        $sessions = DB::table('watch_sessions')->whereBetween('watched_on', [$fromDate, $toDate]);
        $sessionCount = (int) (clone $sessions)->where('watch_seconds', '>', 0)->count();
        $completed = (int) (clone $sessions)->where('completed', true)->count();
        $active = DB::table('active_users')->whereBetween('active_on', [$fromDate, $toDate]);
        $uniqueViewers = (int) (clone $active)->distinct()->count('actor_key');
        $returning = (int) DB::query()->fromSub(
            (clone $active)->select('actor_key')->groupBy('actor_key')->havingRaw('COUNT(DISTINCT active_on) >= 2'), 'r'
        )->count();
        $dauByDay = (clone $active)->select('active_on', DB::raw('COUNT(*) as c'))->groupBy('active_on')->pluck('c', 'active_on')->all();

        // ---- Coins (from the ledger) ----------------------------------------
        $ledger = DB::table('coin_transactions')->whereBetween('created_at', [$from, $to]);
        $coinsByType = (clone $ledger)->select('type', DB::raw('SUM(amount) as total'))->groupBy('type')->pluck('total', 'type')->map(fn ($v) => (int) $v);
        $spentByDay = (clone $ledger)->where('type', 'unlock')->selectRaw('DATE(created_at) as d, -SUM(amount) as v')->groupByRaw('DATE(created_at)')->pluck('v', 'd')->all();
        $boughtByDay = (clone $ledger)->whereIn('type', ['purchase', 'bonus'])->selectRaw('DATE(created_at) as d, SUM(amount) as v')->groupByRaw('DATE(created_at)')->pluck('v', 'd')->all();

        // ---- Payment attempts ---------------------------------------------------
        $attempts = DB::table('payments')->whereBetween('created_at', [$from, $to]);
        $byStatus = (clone $attempts)->select('status', DB::raw('COUNT(*) as c'))->groupBy('status')->pluck('c', 'status')->map(fn ($v) => (int) $v);
        $totalAttempts = (int) $byStatus->sum();
        $succeeded = (int) (($byStatus['success'] ?? 0) + ($byStatus['refunded'] ?? 0));
        $methodNames = DB::table('payment_methods')->pluck('name', 'code');
        $byMethod = (clone $attempts)->select('payment_method_code',
            DB::raw('COUNT(*) as attempts'),
            DB::raw("SUM(CASE WHEN status IN ('success','refunded') THEN 1 ELSE 0 END) as success"),
            DB::raw("SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed"),
            DB::raw("SUM(CASE WHEN status IN ('success','refunded') THEN amount ELSE 0 END) as amount"))
            ->groupBy('payment_method_code')->orderByDesc('attempts')->get()
            ->map(fn ($r) => [
                'method' => $r->payment_method_code,
                'name' => $methodNames[$r->payment_method_code] ?? $r->payment_method_code,
                'attempts' => (int) $r->attempts, 'success' => (int) $r->success, 'failed' => (int) $r->failed, 'amount' => (int) $r->amount,
            ])->values();

        return [
            'period' => ['days' => $days, 'from' => $fromDate, 'to' => $toDate],
            'revenue' => [
                'gross' => $gross,
                'refunds' => $refunds,
                'fees' => $fees,
                'net' => $net,
                'streaming_cost' => $streamingCost,
                'streaming_cost_is_estimate' => $streamingActual === null,
                'operating_costs' => $otherCosts,
                'net_after_costs' => $net - $streamingCost - $otherCosts,
                'by_type' => $byType,
                'chart' => $revenueChart,
            ],
            'audience' => [
                'views' => (int) DB::table('episode_views')->whereBetween('viewed_on', [$fromDate, $toDate])->count(),
                'unique_viewers' => $uniqueViewers,
                'watch_seconds' => $watchSeconds,
                'avg_watch_seconds_per_viewer' => $uniqueViewers ? (int) round($watchSeconds / $uniqueViewers) : 0,
                'sessions' => $sessionCount,
                'completion_rate' => $sessionCount ? round($completed / $sessionCount, 4) : 0,
                'returning_viewers' => $returning,
                'retention_rate' => $uniqueViewers ? round($returning / $uniqueViewers, 4) : 0,
                'playback_errors' => (int) (clone $sessions)->sum('errors'),
                'views_chart' => $this->series(DB::table('episode_views')->whereBetween('viewed_on', [$fromDate, $toDate])
                    ->select('viewed_on', DB::raw('COUNT(*) as c'))->groupBy('viewed_on')->pluck('c', 'viewed_on')->all(), $days),
                'watch_time_chart' => $this->series((clone $sessions)->select('watched_on', DB::raw('SUM(watch_seconds) as s'))
                    ->groupBy('watched_on')->pluck('s', 'watched_on')->all(), $days),
            ],
            'active_users' => [
                'dau' => (int) ($dauByDay[now()->toDateString()] ?? 0),
                'dau_avg' => $days ? (int) round(array_sum($dauByDay) / $days) : 0,
                'mau' => (int) DB::table('active_users')->where('active_on', '>=', now()->subDays(29)->toDateString())->distinct()->count('actor_key'),
                'chart' => $this->series($dauByDay, $days),
            ],
            'coins' => [
                'purchased' => (int) ($coinsByType['purchase'] ?? 0),
                'bonus' => (int) ($coinsByType['bonus'] ?? 0),
                'spent' => -(int) ($coinsByType['unlock'] ?? 0),
                'refunded' => -(int) ($coinsByType['refund'] ?? 0),
                'admin_adjusted' => (int) ($coinsByType['admin_adjust'] ?? 0),
                'outstanding_balance' => (int) DB::table('users')->sum('coins'),
                'chart' => array_map(fn ($d) => ['date' => $d, 'bought' => (int) ($boughtByDay[$d] ?? 0), 'spent' => (int) ($spentByDay[$d] ?? 0)], $this->dates($days)),
            ],
            'payments' => [
                'attempts' => $totalAttempts,
                'success' => $succeeded,
                'failed' => (int) ($byStatus['failed'] ?? 0),
                'pending' => (int) ($byStatus['pending'] ?? 0),
                'cancelled' => (int) ($byStatus['cancelled'] ?? 0),
                'success_rate' => $totalAttempts ? round($succeeded / $totalAttempts, 4) : 0,
                'by_method' => $byMethod,
            ],
            'series' => $this->seriesTable($fromDate, $toDate),
            'alerts' => $this->costAlerts(),
        ];
    }

    /**
     * Revenue and audience per series for the period.
     *
     * @return list<array<string,mixed>>
     */
    public function seriesTable(string $fromDate, string $toDate, ?int $companyId = null): array
    {
        $scope = fn ($q) => $companyId ? $q->where('company_id', $companyId) : $q;

        $revenue = $scope(DB::table('company_earnings')->whereBetween('period_date', [$fromDate, $toDate])->whereNotNull('drama_id'))
            ->select('drama_id', DB::raw('SUM(gross_amount) as gross'), DB::raw('SUM(amount) as creator'))->groupBy('drama_id')->get()->keyBy('drama_id');
        $views = $scope(DB::table('episode_views')->whereBetween('viewed_on', [$fromDate, $toDate]))
            ->select('drama_id', DB::raw('COUNT(*) as c'))->groupBy('drama_id')->pluck('c', 'drama_id');
        $watch = $scope(DB::table('watch_sessions')->whereBetween('watched_on', [$fromDate, $toDate]))
            ->select('drama_id', DB::raw('SUM(watch_seconds) as s'), DB::raw('COUNT(DISTINCT actor_key) as u'),
                DB::raw('SUM(CASE WHEN completed THEN 1 ELSE 0 END) as done'), DB::raw('SUM(CASE WHEN watch_seconds > 0 THEN 1 ELSE 0 END) as n'))
            ->groupBy('drama_id')->get()->keyBy('drama_id');

        $ids = collect($revenue->keys())->merge($views->keys())->merge($watch->keys())->unique();
        if ($ids->isEmpty()) {
            return [];
        }

        return Drama::whereIn('id', $ids)->get(['id', 'title', 'slug', 'poster_url', 'company_id', 'total_episodes'])
            ->map(function (Drama $d) use ($revenue, $views, $watch) {
                $w = $watch[$d->id] ?? null;

                return [
                    'drama_id' => $d->id,
                    'title' => $d->title,
                    'slug' => $d->slug,
                    'poster_url' => $d->poster_url,
                    'revenue_gross' => (int) ($revenue[$d->id]->gross ?? 0),
                    'creator_earnings' => (int) ($revenue[$d->id]->creator ?? 0),
                    'views' => (int) ($views[$d->id] ?? 0),
                    'unique_viewers' => (int) ($w->u ?? 0),
                    'watch_seconds' => (int) ($w->s ?? 0),
                    'completion_rate' => ($w && $w->n) ? round($w->done / $w->n, 4) : 0,
                ];
            })
            ->sortByDesc(fn ($r) => [$r['revenue_gross'], $r['views']])->values()->all();
    }

    /**
     * Per-episode breakdown of one series: revenue, views, watch time, completion and where viewers stop.
     *
     * @return array<string,mixed>
     */
    public function dramaDetail(Drama $drama, int $days = 30): array
    {
        [, , $fromDate, $toDate] = $this->range($days);

        $episodes = $drama->episodes()->approved()->get(['id', 'number', 'title', 'duration_seconds']);
        $views = DB::table('episode_views')->where('drama_id', $drama->id)->whereBetween('viewed_on', [$fromDate, $toDate])
            ->select('episode_id', DB::raw('COUNT(*) as c'))->groupBy('episode_id')->pluck('c', 'episode_id');
        $revenue = DB::table('company_earnings')->where('drama_id', $drama->id)->whereBetween('period_date', [$fromDate, $toDate])
            ->whereNotNull('episode_id')->select('episode_id', DB::raw('SUM(gross_amount) as g'))->groupBy('episode_id')->pluck('g', 'episode_id');
        $sessions = DB::table('watch_sessions')->where('drama_id', $drama->id)->whereBetween('watched_on', [$fromDate, $toDate]);
        $watch = (clone $sessions)->select('episode_id', DB::raw('SUM(watch_seconds) as s'), DB::raw('COUNT(DISTINCT actor_key) as u'),
            DB::raw('SUM(CASE WHEN completed THEN 1 ELSE 0 END) as done'), DB::raw('SUM(CASE WHEN watch_seconds > 0 THEN 1 ELSE 0 END) as n'),
            DB::raw('AVG(CASE WHEN duration_seconds > 0 THEN 1.0 * max_position / duration_seconds END) as pct'))
            ->groupBy('episode_id')->get()->keyBy('episode_id');

        $firstReach = null;
        $rows = $episodes->map(function (Episode $e) use ($drama, $views, $revenue, $watch, &$firstReach) {
            $w = $watch[$e->id] ?? null;
            $reach = (int) ($w->u ?? 0);
            $firstReach ??= $reach;

            return [
                'episode_id' => $e->id,
                'number' => $e->number,
                'title' => $e->title,
                'is_free' => $e->setRelation('drama', $drama)->isFree(),
                'views' => (int) ($views[$e->id] ?? 0),
                'unique_viewers' => $reach,
                'reach_rate' => $firstReach ? round($reach / $firstReach, 4) : 0,
                'watch_seconds' => (int) ($w->s ?? 0),
                'completion_rate' => ($w && $w->n) ? round($w->done / $w->n, 4) : 0,
                'avg_percent_watched' => $w && $w->pct !== null ? round((float) $w->pct, 4) : 0,
                'revenue_gross' => (int) ($revenue[$e->id] ?? 0),
            ];
        })->values();

        // Where unfinished playbacks stopped, in tenths of the episode.
        $dropOff = array_fill(0, 10, 0);
        (clone $sessions)->where('completed', false)->where('duration_seconds', '>', 0)->where('watch_seconds', '>', 0)
            ->select('max_position', 'duration_seconds')->orderBy('id')->chunk(1000, function ($chunk) use (&$dropOff) {
                foreach ($chunk as $s) {
                    $dropOff[min(9, (int) floor(10 * $s->max_position / max(1, $s->duration_seconds)))]++;
                }
            });

        return [
            'drama' => ['id' => $drama->id, 'title' => $drama->title, 'slug' => $drama->slug, 'poster_url' => $drama->poster_url,
                'free_episodes' => (int) $drama->free_episodes, 'coins_per_episode' => (int) $drama->coins_per_episode],
            'period' => ['days' => $days, 'from' => $fromDate, 'to' => $toDate],
            'totals' => [
                'views' => (int) $rows->sum('views'),
                'unique_viewers' => (int) (clone $sessions)->distinct()->count('actor_key'),
                'watch_seconds' => (int) $rows->sum('watch_seconds'),
                'revenue_gross' => (int) DB::table('company_earnings')->where('drama_id', $drama->id)->whereBetween('period_date', [$fromDate, $toDate])->sum('gross_amount'),
            ],
            'episodes' => $rows,
            'drop_off' => array_map(fn ($i) => ['from_percent' => $i * 10, 'to_percent' => $i * 10 + 10, 'sessions' => $dropOff[$i]], range(0, 9)),
        ];
    }

    /**
     * Month-to-date costs against the alert threshold (setting cost_alert_monthly_tzs).
     *
     * @return list<array{level:string,code:string,message:string}>
     */
    public function costAlerts(): array
    {
        $limit = (int) Setting::get('cost_alert_monthly_tzs', 0);
        if ($limit <= 0) {
            return [];
        }
        $monthStart = now()->startOfMonth();
        $watch = (int) DB::table('watch_sessions')->where('watched_on', '>=', $monthStart->toDateString())->sum('watch_seconds');
        $costs = OperatingCost::where('period', $monthStart->toDateString())->select('category', DB::raw('SUM(amount) as t'))
            ->groupBy('category')->pluck('t', 'category')->map(fn ($v) => (int) $v)->all();
        $total = ($costs['streaming'] ?? $this->streamingCost($watch)) + array_sum(array_diff_key($costs, ['streaming' => true]));

        if ($total < $limit * 0.8) {
            return [];
        }

        return [[
            'level' => $total >= $limit ? 'danger' : 'warning',
            'code' => 'monthly_cost',
            'message' => 'Gharama za mwezi huu ni TSh '.number_format($total).' kati ya kikomo cha TSh '.number_format($limit).'.',
            'total' => $total,
            'limit' => $limit,
        ]];
    }
}
