<?php

namespace App\Services;

use App\Models\Company;
use App\Models\CompanyEarning;
use App\Models\Drama;
use App\Models\Episode;
use App\Models\Plan;
use App\Models\Setting;
use App\Models\Subscription;
use Carbon\CarbonInterface;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class EarningsService
{
    public function coinValue(): float
    {
        return (float) Setting::get('coin_value_tzs', 10);
    }

    /** Coin unlock: value = coins_spent × coin TZS value × company share. */
    public function recordCoinUnlock(Episode $episode, int $coinsSpent, int $userId, ?CarbonInterface $at = null): ?CompanyEarning
    {
        return $this->record($episode, 'coins', $coinsSpent * $this->coinValue(), [
            'episode_id' => $episode->id, 'user_id' => $userId, 'coins_spent' => $coinsSpent,
        ], $at);
    }

    /** Episode-pack unlock: value = plan price / episode_quota × company share. */
    public function recordPackUnlock(Episode $episode, Subscription $pack, int $userId, ?CarbonInterface $at = null): ?CompanyEarning
    {
        $plan = $pack->plan ?? Plan::find($pack->plan_id);
        $value = ($plan && $plan->episode_quota) ? $plan->price / $plan->episode_quota : 0;

        return $this->record($episode, 'episode_pack', $value, [
            'episode_id' => $episode->id, 'user_id' => $userId, 'subscription_id' => $pack->id,
        ], $at);
    }

    protected function record(Episode $episode, string $source, float $grossValue, array $meta, ?CarbonInterface $at): ?CompanyEarning
    {
        $drama = $episode->relationLoaded('drama') ? $episode->drama : Drama::find($episode->drama_id);
        $company = $drama?->company;
        if (! $company) {
            return null;
        }
        $amount = (int) round($grossValue * $company->shareFraction());
        if ($amount <= 0) {
            return null;
        }

        return CompanyEarning::create([
            'company_id' => $company->id,
            'drama_id' => $drama->id,
            'source' => $source,
            'amount' => $amount,
            'period_date' => ($at ?? now())->toDateString(),
            'meta' => array_merge($meta, ['gross_value' => round($grossValue, 2), 'share_percent' => (float) $company->revenue_share_percent]),
        ]);
    }

    /**
     * Distribute the day's prorated time-subscription revenue to companies,
     * split by each drama's share of subscriber views that day. Idempotent per date.
     *
     * @return array{date:string,pool:float,subscriber_views:int,rows:int,distributed:int}
     */
    public function distribute(CarbonInterface|string $date): array
    {
        $day = Carbon::parse($date)->startOfDay();
        $dayStr = $day->toDateString();
        $dayEnd = $day->copy()->endOfDay();

        // Subscriptions active at some point during that day.
        $subs = Subscription::query()
            ->with('plan')
            ->whereIn('type', Plan::TIME_TYPES)
            ->whereIn('status', ['active', 'expired'])
            ->where('starts_at', '<=', $dayEnd)
            ->where('ends_at', '>', $day)
            ->get();

        $pool = 0.0;
        foreach ($subs as $sub) {
            $plan = $sub->plan;
            if (! $plan) {
                continue;
            }
            $days = max(1, (int) ($plan->duration_days ?: $sub->starts_at->diffInDays($sub->ends_at)));
            $pool += $plan->price / $days;
        }
        $subscriberIds = $subs->pluck('user_id')->unique()->values()->all();

        return DB::transaction(function () use ($dayStr, $pool, $subscriberIds) {
            CompanyEarning::where('source', 'subscription_pool')->where('period_date', $dayStr)->delete();

            if ($pool <= 0 || empty($subscriberIds)) {
                return ['date' => $dayStr, 'pool' => round($pool, 2), 'subscriber_views' => 0, 'rows' => 0, 'distributed' => 0];
            }

            $byDrama = collect();
            foreach (array_chunk($subscriberIds, 500) as $chunk) {
                $rows = DB::table('episode_views')
                    ->select('drama_id', 'company_id', DB::raw('COUNT(*) as views'))
                    ->where('viewed_on', $dayStr)
                    ->whereIn('user_id', $chunk)
                    ->groupBy('drama_id', 'company_id')
                    ->get();
                foreach ($rows as $r) {
                    $key = $r->drama_id;
                    $prev = $byDrama->get($key);
                    $byDrama->put($key, ['drama_id' => $r->drama_id, 'company_id' => $r->company_id, 'views' => ($prev['views'] ?? 0) + (int) $r->views]);
                }
            }

            $totalViews = (int) $byDrama->sum('views');
            if ($totalViews === 0) {
                return ['date' => $dayStr, 'pool' => round($pool, 2), 'subscriber_views' => 0, 'rows' => 0, 'distributed' => 0];
            }

            $companies = Company::whereIn('id', $byDrama->pluck('company_id')->unique())->get()->keyBy('id');
            $now = now();
            $insert = [];
            $distributed = 0;
            foreach ($byDrama as $row) {
                $company = $companies->get($row['company_id']);
                if (! $company) {
                    continue;
                }
                $gross = $pool * $row['views'] / $totalViews;
                $amount = (int) round($gross * $company->shareFraction());
                if ($amount <= 0) {
                    continue;
                }
                $distributed += $amount;
                $insert[] = [
                    'company_id' => $company->id,
                    'drama_id' => $row['drama_id'],
                    'source' => 'subscription_pool',
                    'amount' => $amount,
                    'period_date' => $dayStr,
                    'meta' => json_encode([
                        'views' => $row['views'], 'total_subscriber_views' => $totalViews,
                        'pool' => round($pool, 2), 'share_percent' => (float) $company->revenue_share_percent,
                    ]),
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }
            foreach (array_chunk($insert, 200) as $chunk) {
                CompanyEarning::insert($chunk);
            }

            return ['date' => $dayStr, 'pool' => round($pool, 2), 'subscriber_views' => $totalViews, 'rows' => count($insert), 'distributed' => $distributed];
        });
    }
}
