<?php

namespace App\Services;

use App\Models\Company;
use App\Models\Drama;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

class StatsService
{
    /**
     * Build a continuous [{date, value}] series for the last $days days (inclusive of today).
     *
     * @param  callable(Builder):Builder  $scope  extra where-clauses
     * @return array<int,array{date:string,value:int}>
     */
    public function dailySeries(string $table, string $dateExpr, string $valueExpr, int $days = 30, ?callable $scope = null): array
    {
        $from = now()->subDays($days - 1)->toDateString();

        $q = DB::table($table)
            ->selectRaw("{$dateExpr} as d, {$valueExpr} as v")
            ->whereRaw("{$dateExpr} >= ?", [$from])
            ->groupByRaw($dateExpr);
        if ($scope) {
            $scope($q);
        }
        $map = $q->pluck('v', 'd')->all();

        $series = [];
        for ($i = $days - 1; $i >= 0; $i--) {
            $date = now()->subDays($i)->toDateString();
            $series[] = ['date' => $date, 'value' => (int) round((float) ($map[$date] ?? 0))];
        }

        return $series;
    }

    public function revenueChart(int $days = 30): array
    {
        return $this->dailySeries('payments', 'DATE(paid_at)', 'SUM(amount)', $days,
            fn ($q) => $q->where('status', 'success'));
    }

    public function viewsChart(?int $companyId = null, int $days = 30): array
    {
        return $this->dailySeries('episode_views', 'viewed_on', 'COUNT(*)', $days,
            fn ($q) => $companyId ? $q->where('company_id', $companyId) : $q);
    }

    public function earningsChart(?int $companyId = null, int $days = 30): array
    {
        return $this->dailySeries('company_earnings', 'period_date', 'SUM(amount)', $days,
            fn ($q) => $companyId ? $q->where('company_id', $companyId) : $q);
    }

    /** Full stats block for a company (used by studio dashboard and admin company stats). */
    public function companyStats(Company $company): array
    {
        $id = $company->id;
        $today = now()->toDateString();
        $from30 = now()->subDays(29)->toDateString();
        $monthStart = now()->startOfMonth()->toDateString();

        $viewsTotal = (int) Drama::where('company_id', $id)->sum('views');
        $viewsToday = DB::table('episode_views')->where('company_id', $id)->where('viewed_on', $today)->count();
        $views30 = DB::table('episode_views')->where('company_id', $id)->where('viewed_on', '>=', $from30)->count();
        $watchers = (int) DB::table('episode_views')->where('company_id', $id)->whereNotNull('user_id')->distinct()->count('user_id');
        $watchers30 = (int) DB::table('episode_views')->where('company_id', $id)->whereNotNull('user_id')->where('viewed_on', '>=', $from30)->distinct()->count('user_id');

        $earnTotal = (int) DB::table('company_earnings')->where('company_id', $id)->sum('amount');
        $earnMonth = (int) DB::table('company_earnings')->where('company_id', $id)->where('period_date', '>=', $monthStart)->sum('amount');
        $paidOut = (int) DB::table('payouts')->where('company_id', $id)->where('status', 'paid')->sum('amount');
        $pendingPayouts = (int) DB::table('payouts')->where('company_id', $id)->where('status', 'pending')->sum('amount');

        $earnBySource = DB::table('company_earnings')->where('company_id', $id)
            ->select('source', DB::raw('SUM(amount) as total'))->groupBy('source')->pluck('total', 'source')
            ->map(fn ($v) => (int) $v)->all();

        $dramaViews30 = DB::table('episode_views')->where('company_id', $id)->where('viewed_on', '>=', $from30)
            ->select('drama_id', DB::raw('COUNT(*) as c'))->groupBy('drama_id')->pluck('c', 'drama_id')->all();
        $dramaEarnings = DB::table('company_earnings')->where('company_id', $id)->whereNotNull('drama_id')
            ->select('drama_id', DB::raw('SUM(amount) as s'))->groupBy('drama_id')->pluck('s', 'drama_id')->all();
        $dramaWatchers = DB::table('episode_views')->where('company_id', $id)->whereNotNull('user_id')
            ->select('drama_id', DB::raw('COUNT(DISTINCT user_id) as c'))->groupBy('drama_id')->pluck('c', 'drama_id')->all();

        $dramas = Drama::where('company_id', $id)->orderByDesc('views')->get()->map(fn (Drama $d) => [
            'id' => $d->id,
            'title' => $d->title,
            'slug' => $d->slug,
            'poster_url' => $d->poster_url,
            'status' => $d->status,
            'badge' => $d->badge,
            'episodes' => (int) $d->total_episodes,
            'views' => (int) $d->views,
            'views_30d' => (int) ($dramaViews30[$d->id] ?? 0),
            'watchers' => (int) ($dramaWatchers[$d->id] ?? 0),
            'earnings' => (int) ($dramaEarnings[$d->id] ?? 0),
        ])->values();

        return [
            'company' => ['id' => $company->id, 'name' => $company->name, 'slug' => $company->slug,
                'revenue_share_percent' => (float) $company->revenue_share_percent],
            'views' => ['total' => $viewsTotal, 'today' => $viewsToday, 'last_30d' => $views30],
            'unique_watchers' => $watchers,
            'unique_watchers_30d' => $watchers30,
            'earnings' => [
                'total' => $earnTotal,
                'month' => $earnMonth,
                'paid_out' => $paidOut,
                'pending_payout' => max(0, $earnTotal - $paidOut),
                'requested_payouts' => $pendingPayouts,
                'by_source' => (object) $earnBySource,
            ],
            'dramas_count' => $dramas->count(),
            'episodes_count' => (int) $dramas->sum('episodes'),
            'views_chart' => $this->viewsChart($id),
            'earnings_chart' => $this->earningsChart($id),
            'dramas' => $dramas,
        ];
    }
}
