<?php

namespace Database\Seeders;

use App\Models\Company;
use App\Models\Drama;
use App\Models\Payment;
use App\Models\Plan;
use App\Models\Setting;
use App\Models\Subscription;
use App\Models\User;
use App\Services\EarningsService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * ~60 days of synthetic activity so dashboards have life:
 * demo viewers, payments, subscriptions, episode views (bulk), unlocks, company earnings, payouts,
 * plus personal data (favorites/history/VIP sub) for the seeded demo viewers.
 */
class ActivitySeeder extends Seeder
{
    protected const DAYS = 60;

    public function run(): void
    {
        mt_srand(424242);
        $now = now();
        $plans = Plan::all()->keyBy('id');
        $plansByName = $plans->keyBy('name');
        $dramas = Drama::with('company')->get();
        $companies = Company::all()->keyBy('id');
        $coinValue = (float) Setting::get('coin_value_tzs', 10);

        // ---------------------------------------------------------------- viewers
        $first = ['Amani', 'Zawadi', 'Juma', 'Neema', 'Baraka', 'Rehema', 'Hamisi', 'Faraja', 'Wanjiru', 'Otieno', 'Chiamaka', 'Tunde',
            'Aisha', 'Kofi', 'Imani', 'Salma', 'Daudi', 'Halima', 'Emeka', 'Njeri', 'Mussa', 'Grace', 'Said', 'Mwanaidi', 'Kelechi', 'Akinyi'];
        $last = ['Mushi', 'Mollel', 'Mwakalinga', 'Kimaro', 'Mrema', 'Kariuki', 'Odhiambo', 'Okafor', 'Adeyemi', 'Massawe', 'Njoroge',
            'Juma', 'Lyimo', 'Shirima', 'Mbwambo', 'Chukwu', 'Nyerere', 'Kombo', 'Hassan', 'Mwangi'];
        $password = Hash::make('password');
        $rows = [];
        for ($i = 1; $i <= 180; $i++) {
            $created = $now->copy()->subDays(mt_rand(0, 120))->subMinutes(mt_rand(0, 1440));
            $rows[] = [
                'name' => $first[array_rand($first)].' '.$last[array_rand($last)],
                'email' => "viewer{$i}@demo.afriva.com",
                'phone' => '+2557'.str_pad((string) (10000000 + $i * 7919), 8, '0', STR_PAD_LEFT),
                'password' => $password,
                'role' => 'viewer',
                'coins' => mt_rand(0, 6) * 30,
                'status' => $i % 47 === 0 ? 'suspended' : 'active',
                'created_at' => $created,
                'updated_at' => $created,
            ];
        }
        foreach (array_chunk($rows, 100) as $chunk) {
            DB::table('users')->insert($chunk);
        }
        $viewerIds = User::where('email', 'like', '%@demo.afriva.com')->pluck('id')->all();

        // ---------------------------------------------------------------- payments + subscriptions
        $planWeights = ['VIP ya Wiki' => 28, 'VIP ya Mwezi' => 30, 'VIP ya Mwaka' => 4, 'Episode 6' => 10, 'Episode 15' => 5, 'Coins 100' => 14, 'Coins 550' => 9];
        $methodWeights = ['mpesa' => 36, 'tigopesa' => 20, 'airtelmoney' => 15, 'halopesa' => 8, 'tpesa' => 3, 'visa' => 8, 'mastercard' => 5, 'crdb' => 3, 'nmb' => 1, 'nbc' => 1];

        /** @var array<int,array{user_id:int,starts:Carbon,ends:Carbon}> $timeSubs */
        $timeSubs = [];
        $packSubs = []; // user_id => [subscription_id, plan]
        DB::transaction(function () use ($now, $plansByName, $planWeights, $methodWeights, $viewerIds, &$timeSubs, &$packSubs) {
            for ($d = self::DAYS; $d >= 0; $d--) {
                $day = $now->copy()->subDays($d)->startOfDay();
                $count = 4 + (int) round((self::DAYS - $d) / 8) + mt_rand(0, 5);
                for ($k = 0; $k < $count; $k++) {
                    $at = $day->copy()->addSeconds(mt_rand(6 * 3600, 23 * 3600));
                    if ($at->isFuture()) {
                        $at = $now->copy()->subMinutes(mt_rand(1, 300));
                    }
                    $plan = $plansByName[$this->weighted($planWeights)];
                    $method = $this->weighted($methodWeights);
                    $roll = mt_rand(1, 100);
                    $status = $roll <= 87 ? 'success' : ($roll <= 94 ? 'failed' : ($d <= 2 ? 'pending' : 'cancelled'));
                    $userId = $viewerIds[array_rand($viewerIds)];

                    $payment = Payment::create([
                        'user_id' => $userId,
                        'plan_id' => $plan->id,
                        'payment_method_code' => $method,
                        'reference' => 'AFV-'.$at->format('ymd').'-'.Str::upper(Str::random(8)),
                        'amount' => $plan->price,
                        'currency' => 'TZS',
                        'phone' => in_array($method, ['visa', 'mastercard', 'crdb', 'nmb', 'nbc'], true) ? null : '+2557'.mt_rand(10000000, 99999999),
                        'status' => $status,
                        'provider_reference' => $status === 'success' ? 'SBX-'.Str::upper(Str::random(10)) : null,
                        'meta' => ['driver' => 'sandbox', 'seeded' => true, 'fulfilled' => $status === 'success'],
                        'paid_at' => $status === 'success' ? $at : null,
                        'created_at' => $at,
                        'updated_at' => $at,
                    ]);

                    if ($status !== 'success') {
                        continue;
                    }
                    if ($plan->isTimeBased()) {
                        $ends = $at->copy()->addDays($plan->duration_days);
                        Subscription::create([
                            'user_id' => $userId, 'plan_id' => $plan->id, 'payment_id' => $payment->id, 'type' => $plan->type,
                            'starts_at' => $at, 'ends_at' => $ends, 'status' => $ends->isFuture() ? 'active' : 'expired',
                            'created_at' => $at, 'updated_at' => $at,
                        ]);
                        $timeSubs[] = ['user_id' => $userId, 'starts' => $at, 'ends' => $ends];
                    } elseif ($plan->type === 'episodes') {
                        $sub = Subscription::create([
                            'user_id' => $userId, 'plan_id' => $plan->id, 'payment_id' => $payment->id, 'type' => 'episodes',
                            'starts_at' => $at, 'ends_at' => null, 'episodes_remaining' => $plan->episode_quota, 'status' => 'active',
                            'created_at' => $at, 'updated_at' => $at,
                        ]);
                        $packSubs[] = ['id' => $sub->id, 'user_id' => $userId, 'plan' => $plan, 'at' => $at, 'remaining' => $plan->episode_quota];
                    } else {
                        DB::table('users')->where('id', $userId)->increment('coins', (int) $plan->coins + (int) $plan->bonus_coins);
                    }
                }
            }
        });

        // ---------------------------------------------------------------- episode views (bulk)
        $episodesByDrama = DB::table('episodes')->select('id', 'drama_id', 'number')->orderBy('number')->get()->groupBy('drama_id')
            ->map(fn ($g) => $g->pluck('id', 'number')->all())->all();
        $dramaWeights = $dramas->mapWithKeys(fn ($d) => [$d->id => max(1, (int) ($d->views / 10000))])->all();
        $dramaById = $dramas->keyBy('id');

        $viewRows = [];
        $inserted = 0;
        for ($d = self::DAYS; $d >= 0; $d--) {
            $day = $now->copy()->subDays($d);
            $dayStr = $day->toDateString();
            $activeSubscribers = array_values(array_unique(array_map(fn ($s) => $s['user_id'], array_filter(
                $timeSubs, fn ($s) => $s['starts']->lte($day->copy()->endOfDay()) && $s['ends']->gt($day->copy()->startOfDay())
            ))));
            $n = 260 + (int) ((self::DAYS - $d) * 6.5) + mt_rand(-40, 60) + ($day->isWeekend() ? 90 : 0);
            for ($k = 0; $k < $n; $k++) {
                $dramaId = $this->weighted($dramaWeights);
                $drama = $dramaById[$dramaId];
                $eps = $episodesByDrama[$dramaId];
                $number = 1 + (int) floor(count($eps) * pow(mt_rand() / mt_getrandmax(), 1.8));
                $number = min($number, count($eps));
                $r = mt_rand(1, 100);
                $userId = null;
                if ($r <= 35 && $activeSubscribers) {
                    $userId = $activeSubscribers[array_rand($activeSubscribers)];
                } elseif ($r <= 70) {
                    $userId = $viewerIds[array_rand($viewerIds)];
                }
                $ts = $day->copy()->startOfDay()->addSeconds(mt_rand(0, 86399));
                if ($ts->isFuture()) {
                    $ts = $now->copy()->subSeconds(mt_rand(1, 3600));
                }
                $viewRows[] = [
                    'episode_id' => $eps[$number],
                    'drama_id' => $dramaId,
                    'company_id' => $drama->company_id,
                    'user_id' => $userId,
                    'viewed_on' => $dayStr,
                    'created_at' => $ts,
                    'updated_at' => $ts,
                ];
                if (count($viewRows) >= 500) {
                    DB::table('episode_views')->insert($viewRows);
                    $inserted += count($viewRows);
                    $viewRows = [];
                }
            }
        }
        if ($viewRows) {
            DB::table('episode_views')->insert($viewRows);
        }

        // Watch history for viewers (last episode they reached per drama).
        $histories = DB::table('episode_views')->whereNotNull('user_id')
            ->select('user_id', 'drama_id', DB::raw('MAX(episode_id) as episode_id'), DB::raw('MAX(created_at) as last_at'))
            ->groupBy('user_id', 'drama_id')->get();
        $hRows = $histories->map(fn ($h) => [
            'user_id' => $h->user_id, 'drama_id' => $h->drama_id, 'episode_id' => $h->episode_id,
            'progress_seconds' => mt_rand(5, 120), 'created_at' => $h->last_at, 'updated_at' => $h->last_at,
        ])->all();
        foreach (array_chunk($hRows, 400) as $chunk) {
            DB::table('watch_histories')->insert($chunk);
        }

        // ---------------------------------------------------------------- unlocks + immediate earnings
        $unlockRows = [];
        $earningRows = [];
        $seen = [];
        $lockedPick = function () use ($dramas, $episodesByDrama) {
            $drama = $dramas->random();
            $eps = $episodesByDrama[$drama->id];
            $n = mt_rand($drama->free_episodes + 1, max($drama->free_episodes + 1, count($eps)));

            return [$drama, $eps[$n] ?? end($eps)];
        };

        // Coin unlocks spread over the period.
        for ($i = 0; $i < 700; $i++) {
            [$drama, $episodeId] = $lockedPick();
            $userId = $viewerIds[array_rand($viewerIds)];
            if (isset($seen["$userId-$episodeId"])) {
                continue;
            }
            $seen["$userId-$episodeId"] = true;
            $at = $now->copy()->subDays(mt_rand(0, self::DAYS))->setTime(mt_rand(6, 23), mt_rand(0, 59));
            if ($at->isFuture()) {
                $at = $now->copy()->subMinutes(mt_rand(1, 300));
            }
            $coins = $drama->coins_per_episode;
            $unlockRows[] = ['user_id' => $userId, 'episode_id' => $episodeId, 'method' => 'coins', 'coins_spent' => $coins,
                'subscription_id' => null, 'created_at' => $at, 'updated_at' => $at];
            $company = $companies[$drama->company_id];
            $earningRows[] = $this->earningRow($company, $drama->id, 'coins', $coins * $coinValue, $at,
                ['episode_id' => $episodeId, 'user_id' => $userId, 'coins_spent' => $coins]);
        }

        // Episode-pack unlocks consume the seeded packs.
        $packUpdates = [];
        foreach ($packSubs as $pack) {
            $use = mt_rand(1, $pack['remaining']);
            for ($u = 0; $u < $use; $u++) {
                [$drama, $episodeId] = $lockedPick();
                if (isset($seen["{$pack['user_id']}-$episodeId"])) {
                    continue;
                }
                $seen["{$pack['user_id']}-$episodeId"] = true;
                $at = $pack['at']->copy()->addHours(mt_rand(0, 24 * 5));
                if ($at->isFuture()) {
                    $at = $now->copy()->subMinutes(mt_rand(1, 120));
                }
                $unlockRows[] = ['user_id' => $pack['user_id'], 'episode_id' => $episodeId, 'method' => 'episode_pack', 'coins_spent' => 0,
                    'subscription_id' => $pack['id'], 'created_at' => $at, 'updated_at' => $at];
                $earningRows[] = $this->earningRow($companies[$drama->company_id], $drama->id, 'episode_pack',
                    $pack['plan']->price / $pack['plan']->episode_quota, $at,
                    ['episode_id' => $episodeId, 'user_id' => $pack['user_id'], 'subscription_id' => $pack['id']]);
                $pack['remaining']--;
            }
            $packUpdates[$pack['id']] = $pack['remaining'];
        }
        foreach ($packUpdates as $id => $remaining) {
            DB::table('subscriptions')->where('id', $id)->update([
                'episodes_remaining' => $remaining, 'status' => $remaining > 0 ? 'active' : 'expired',
            ]);
        }
        foreach (array_chunk($unlockRows, 400) as $chunk) {
            DB::table('episode_unlocks')->insert($chunk);
        }
        foreach (array_chunk($earningRows, 300) as $chunk) {
            DB::table('company_earnings')->insert($chunk);
        }

        // ---------------------------------------------------------------- subscription pool distribution
        $earnings = app(EarningsService::class);
        for ($d = self::DAYS; $d >= 1; $d--) {
            $earnings->distribute($now->copy()->subDays($d));
        }

        // ---------------------------------------------------------------- payouts
        foreach ($companies as $company) {
            $older = (int) DB::table('company_earnings')->where('company_id', $company->id)
                ->where('period_date', '<', $now->copy()->subDays(30)->toDateString())->sum('amount');
            if ($older > 0) {
                $paidAt = $now->copy()->subDays(28)->setTime(11, 0);
                DB::table('payouts')->insert([
                    'company_id' => $company->id, 'amount' => (int) round($older * 0.9), 'status' => 'paid',
                    'reference' => 'PO-'.$paidAt->format('ymd').'-'.$company->id, 'paid_at' => $paidAt,
                    'notes' => 'Monthly settlement (bank transfer)', 'created_at' => $paidAt, 'updated_at' => $paidAt,
                ]);
            }
            $recent = (int) DB::table('company_earnings')->where('company_id', $company->id)
                ->where('period_date', '>=', $now->copy()->subDays(30)->toDateString())->sum('amount');
            if ($recent > 0) {
                DB::table('payouts')->insert([
                    'company_id' => $company->id, 'amount' => (int) round($recent * 0.5), 'status' => 'pending',
                    'reference' => 'PO-'.$now->format('ymd').'-'.$company->id, 'paid_at' => null,
                    'notes' => 'Scheduled mid-month settlement', 'created_at' => $now, 'updated_at' => $now,
                ]);
            }
        }

        $this->seedDemoViewers($plansByName, $dramas, $episodesByDrama);
    }

    protected function seedDemoViewers($plansByName, $dramas, array $episodesByDrama): void
    {
        $now = now();
        $vip = User::where('email', 'vip@afriva.com')->first();
        $viewer = User::where('email', 'viewer@afriva.com')->first();
        $monthly = $plansByName['VIP ya Mwezi'];

        if ($vip) {
            $paidAt = $now->copy()->subDays(4)->setTime(20, 15);
            $payment = Payment::create([
                'user_id' => $vip->id, 'plan_id' => $monthly->id, 'payment_method_code' => 'mpesa',
                'reference' => 'AFV-'.$paidAt->format('ymd').'-VIPDEMO1', 'amount' => $monthly->price, 'currency' => 'TZS',
                'phone' => $vip->phone, 'status' => 'success', 'provider_reference' => 'SBX-VIPDEMO0001',
                'meta' => ['driver' => 'sandbox', 'seeded' => true, 'fulfilled' => true], 'paid_at' => $paidAt,
                'created_at' => $paidAt, 'updated_at' => $paidAt,
            ]);
            Subscription::create([
                'user_id' => $vip->id, 'plan_id' => $monthly->id, 'payment_id' => $payment->id, 'type' => 'monthly',
                'starts_at' => $paidAt, 'ends_at' => $paidAt->copy()->addDays(30), 'status' => 'active',
            ]);
        }

        foreach ([$viewer, $vip] as $idx => $user) {
            if (! $user) {
                continue;
            }
            $picks = $dramas->sortByDesc('views')->values()->slice($idx * 3, 6);
            foreach ($picks as $j => $drama) {
                DB::table('favorites')->insertOrIgnore(['user_id' => $user->id, 'drama_id' => $drama->id,
                    'created_at' => $now->copy()->subDays($j), 'updated_at' => $now->copy()->subDays($j)]);
                if ($j < 4) {
                    $epNumber = min(count($episodesByDrama[$drama->id]), $j + 2);
                    DB::table('watch_histories')->updateOrInsert(
                        ['user_id' => $user->id, 'drama_id' => $drama->id],
                        ['episode_id' => $episodesByDrama[$drama->id][$epNumber], 'progress_seconds' => 30 + $j * 15,
                            'created_at' => $now->copy()->subHours($j * 5), 'updated_at' => $now->copy()->subHours($j * 5)]
                    );
                }
            }
        }
    }

    protected function earningRow(Company $company, int $dramaId, string $source, float $gross, Carbon $at, array $meta): array
    {
        return [
            'company_id' => $company->id,
            'drama_id' => $dramaId,
            'episode_id' => $meta['episode_id'] ?? null,
            'source' => $source,
            'amount' => (int) round($gross * $company->shareFraction()),
            'gross_amount' => (int) round($gross),
            'period_date' => $at->toDateString(),
            'meta' => json_encode(array_merge($meta, ['gross_value' => round($gross, 2), 'share_percent' => (float) $company->revenue_share_percent])),
            'created_at' => $at,
            'updated_at' => $at,
        ];
    }

    /** @param array<string|int,int> $weights */
    protected function weighted(array $weights): string|int
    {
        $total = array_sum($weights);
        $r = mt_rand(1, $total);
        foreach ($weights as $key => $w) {
            $r -= $w;
            if ($r <= 0) {
                return $key;
            }
        }

        return array_key_first($weights);
    }
}
