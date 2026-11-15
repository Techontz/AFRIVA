<?php

namespace App\Services\Infra;

use App\Models\Setting;
use App\Services\Infra\Providers\AppProvider;
use App\Services\Infra\Providers\BunnyProvider;
use App\Services\Infra\Providers\DatabaseProvider;
use App\Services\Infra\Providers\HetznerProvider;
use App\Services\Infra\Providers\Provider;
use App\Services\Infra\Providers\R2Provider;
use App\Services\Infra\Providers\ServerProvider;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Throwable;

/**
 * Snapshot for the admin Infrastructure page and the budget alerts. Every section carries `configured`,
 * `ok`, `source` and `as_of`; unconfigured providers are never called. Each provider's result is cached
 * (config infra.cache_ttl, default 10 minutes); failures are cached for one minute and never thrown.
 *
 * Monitoring reports spending, it does not cap it.
 */
class InfraMetrics
{
    public const TAG_LIVE = 'live_usage';

    public const TAG_ESTIMATE = 'estimate';

    public const TAG_BILLED = 'billed';

    public const CACHE_PREFIX = 'infra:v1:';

    /** @return array<int,Provider> */
    public function providers(): array
    {
        return [
            app(ServerProvider::class),
            app(DatabaseProvider::class),
            app(AppProvider::class),
            app(HetznerProvider::class),
            app(BunnyProvider::class),
            app(R2Provider::class),
        ];
    }

    /** @return array<string,mixed> */
    public function snapshot(bool $fresh = false): array
    {
        $sections = [];
        foreach ($this->providers() as $provider) {
            $sections[$provider->key()] = $this->section($provider, $fresh);
        }
        $cost = $this->cost($sections);

        return [
            'generated_at' => now()->toIso8601String(),
            'cache_ttl_seconds' => (int) config('infra.cache_ttl', 600),
            'sections' => $sections,
            'cost' => $cost,
            'budget' => $this->budget($cost['total_usd']),
            'spend_controls' => [
                'capped' => ['hetzner_fixed_price', 'vercel_spend_management', 'r2_alerts_only'],
                'not_capped' => ['bunny_bandwidth'],
            ],
        ];
    }

    /** @return array<string,mixed> */
    protected function section(Provider $provider, bool $fresh): array
    {
        $base = ['key' => $provider->key(), 'source' => $provider->source(), 'configured' => $provider->configured()];
        if (! $base['configured']) {
            return $base + ['ok' => false, 'as_of' => null, 'env' => $provider->requiredEnv(), 'data' => null];
        }

        $key = self::CACHE_PREFIX.$provider->key();
        if (! $fresh && is_array($cached = Cache::get($key))) {
            return $base + $cached;
        }

        try {
            $result = ['ok' => true, 'as_of' => now()->toIso8601String(), 'data' => $provider->collect()];
            Cache::put($key, $result, (int) config('infra.cache_ttl', 600));
        } catch (Throwable $e) {
            report($e);
            // Never echo the raw message: provider errors can include request URLs.
            $result = ['ok' => false, 'as_of' => now()->toIso8601String(), 'data' => null, 'error' => $this->errorLabel($e)];
            Cache::put($key, $result, 60);
        }

        return $base + $result;
    }

    protected function errorLabel(Throwable $e): string
    {
        if ($e instanceof RequestException) {
            return 'HTTP '.$e->response->status();
        }
        if ($e instanceof ConnectionException) {
            return 'Connection failed';
        }

        return class_basename($e);
    }

    /** Elapsed share of the current month, at least 3 days, for projecting month-to-date usage. */
    protected function monthFraction(): float
    {
        $start = now()->startOfMonth();
        $days = $start->daysInMonth;
        $elapsedDays = max(3, $start->diffInSeconds(now()) / 86400);

        return min(1, $elapsedDays / $days);
    }

    /**
     * @param  array<string,array<string,mixed>>  $s
     * @return array{currency:string,total_usd:float,complete:bool,lines:array<int,array<string,mixed>>}
     */
    public function cost(array $s): array
    {
        $eurUsd = (float) config('infra.eur_to_usd', 1.08);
        $lines = [];

        // Hetzner: list price of the server type (+ backups). Fixed, so it is the full month.
        $h = $s['hetzner'] ?? null;
        if ($h && $h['ok'] && ($h['data']['price_monthly_gross_eur'] ?? null) !== null) {
            $eur = (float) $h['data']['price_monthly_gross_eur'];
            $eur += $eur * (float) $h['data']['backup_percent'] / 100;
            $lines[] = $this->line('hetzner', 'Hetzner server', $eur * $eurUsd, self::TAG_ESTIMATE, 'hetzner_list_price', ['eur' => round($eur, 2)]);
        } else {
            $eur = (float) config('infra.hetzner.fallback_monthly_eur', 8.99);
            if (config('infra.hetzner.backups_enabled', true)) {
                $eur += $eur * (float) config('infra.hetzner.backup_percent', 20) / 100;
            }
            $lines[] = $this->line('hetzner', 'Hetzner server', $eur * $eurUsd, self::TAG_ESTIMATE, 'config_price', ['eur' => round($eur, 2)]);
        }

        // Bunny: billed month-to-date projected to the full month, or usage x unit prices.
        $b = $s['bunny'] ?? null;
        $bunnyCfg = config('infra.bunny');
        $fraction = $this->monthFraction();
        if ($b && $b['ok'] && ($b['data']['billing']['this_month_charges'] ?? null) !== null) {
            $billed = (float) $b['data']['billing']['this_month_charges'];
            $projected = max((float) $bunnyCfg['monthly_minimum_usd'], $billed / $fraction);
            $lines[] = $this->line('bunny', 'Bunny Stream', $projected, self::TAG_ESTIMATE, 'projected_from_billed', [
                'billed_to_date_usd' => round($billed, 2), 'billed_tag' => self::TAG_BILLED,
            ]);
        } elseif ($b && $b['ok']) {
            $storageGb = ($b['data']['storage_bytes'] ?? 0) / 1_000_000_000;
            $storage = $storageGb * (float) $bunnyCfg['storage_usd_per_gb'] * max(1, (int) $bunnyCfg['storage_regions']);
            $bwBytes = $b['data']['bandwidth_month_bytes'] ?? null;
            $bandwidth = $bwBytes !== null ? ($bwBytes / 1_000_000_000) / $fraction * (float) $bunnyCfg['bandwidth_usd_per_gb'] : 0.0;
            $lines[] = $this->line('bunny', 'Bunny Stream', max((float) $bunnyCfg['monthly_minimum_usd'], $storage + $bandwidth),
                self::TAG_ESTIMATE, $bwBytes !== null ? 'usage_x_unit_price' : 'storage_only_no_bandwidth', [
                    'storage_usd' => round($storage, 2), 'bandwidth_usd' => round($bandwidth, 2),
                ]);
        } else {
            $lines[] = $this->line('bunny', 'Bunny Stream', null, self::TAG_ESTIMATE, $b && $b['configured'] ? 'unavailable' : 'not_connected');
        }

        // R2: storage beyond the free tier plus projected operations beyond the free tier.
        $r = $s['r2'] ?? null;
        $r2 = config('infra.r2');
        if ($r && $r['ok']) {
            $gb = ($r['data']['storage_bytes'] ?? 0) / 1_000_000_000;
            $storage = max(0, $gb - (float) $r2['free_storage_gb']) * (float) $r2['storage_usd_per_gb_month'];
            $a = ($r['data']['class_a_month'] ?? 0) / 1_000_000 / $fraction;
            $bOps = ($r['data']['class_b_month'] ?? 0) / 1_000_000 / $fraction;
            $ops = max(0, $a - (float) $r2['free_class_a_millions']) * (float) $r2['class_a_usd_per_million']
                + max(0, $bOps - (float) $r2['free_class_b_millions']) * (float) $r2['class_b_usd_per_million'];
            $lines[] = $this->line('r2', 'Cloudflare R2', $storage + $ops, self::TAG_ESTIMATE, 'usage_x_unit_price', [
                'storage_usd' => round($storage, 2), 'operations_usd' => round($ops, 2),
            ]);
        } else {
            $lines[] = $this->line('r2', 'Cloudflare R2', null, self::TAG_ESTIMATE, $r && $r['configured'] ? 'unavailable' : 'not_connected');
        }

        $lines[] = $this->line('vercel', 'Vercel', (float) config('infra.fixed.vercel', 20), self::TAG_ESTIMATE, 'config_price');
        $lines[] = $this->line('cloudflare', 'Cloudflare DNS and proxy', (float) config('infra.fixed.cloudflare', 0), self::TAG_ESTIMATE, 'config_price');

        $known = array_filter($lines, fn ($l) => $l['amount_usd'] !== null);

        return [
            'currency' => 'USD',
            'total_usd' => round(array_sum(array_column($known, 'amount_usd')), 2),
            'complete' => count($known) === count($lines),
            'lines' => $lines,
        ];
    }

    /** @return array<string,mixed> */
    protected function line(string $provider, string $label, ?float $usd, string $tag, string $basis, array $extra = []): array
    {
        return ['provider' => $provider, 'label' => $label, 'amount_usd' => $usd === null ? null : round($usd, 2),
            'tag' => $tag, 'basis' => $basis] + $extra;
    }

    public function budgetUsd(): ?float
    {
        $setting = Setting::where('key', 'infra_monthly_budget_usd')->value('value');
        $value = is_numeric($setting) && (float) $setting > 0 ? $setting : config('infra.monthly_budget_usd');

        return is_numeric($value) && (float) $value > 0 ? round((float) $value, 2) : null;
    }

    /** @return array<string,mixed> */
    public function budget(float $totalUsd): array
    {
        $budget = $this->budgetUsd();
        $percent = $budget ? round($totalUsd / $budget * 100, 1) : null;
        $sent = BudgetAlerts::sentThisMonth();

        return [
            'monthly_budget_usd' => $budget,
            'estimated_total_usd' => $totalUsd,
            'percent' => $percent,
            'thresholds' => array_map(fn (int $t) => [
                'percent' => $t,
                'reached' => $percent !== null && $percent >= $t,
                'alert_sent' => in_array($t, $sent, true),
            ], BudgetAlerts::thresholds()),
            'month' => Carbon::now()->format('Y-m'),
            'alert_email_configured' => filled(BudgetAlerts::recipient()),
        ];
    }

    public static function flushCache(): void
    {
        foreach (['server', 'database', 'app', 'hetzner', 'bunny', 'r2'] as $key) {
            Cache::forget(self::CACHE_PREFIX.$key);
        }
    }
}
