<?php

namespace App\Services\Infra\Providers;

use App\Services\BunnyStream;
use Throwable;

/**
 * Bunny (docs.bunny.net). With only the Stream library key: video count and summed video storage (live usage).
 * With BUNNY_ACCOUNT_API_KEY too: library storage and traffic, account bandwidth this month and billing
 * (ThisMonthCharges = billed so far this month; Balance = prepaid credit, not a charge).
 */
class BunnyProvider extends Provider
{
    public const STREAM = 'https://video.bunnycdn.com';

    public const ACCOUNT = 'https://api.bunny.net';

    public function __construct(protected BunnyStream $bunny) {}

    public function key(): string
    {
        return 'bunny';
    }

    public function source(): string
    {
        return filled(config('infra.bunny.account_api_key')) ? 'Bunny Stream and account API' : 'Bunny Stream API';
    }

    public function configured(): bool
    {
        return $this->bunny->enabled();
    }

    public function requiredEnv(): array
    {
        return ['BUNNY_STREAM_LIBRARY_ID', 'BUNNY_STREAM_API_KEY', 'BUNNY_STREAM_CDN_HOSTNAME', 'BUNNY_ACCOUNT_API_KEY'];
    }

    public function collect(): array
    {
        $library = $this->bunny->libraryId();
        $out = ['library_id' => $library, 'account_connected' => filled(config('infra.bunny.account_api_key'))];

        // Stream API: video count, plus storage summed over the videos (up to 10 000) when no account key.
        $stream = $this->http()->withHeaders(['AccessKey' => (string) config('services.bunny.api_key')]);
        $storage = 0;
        $page = 1;
        do {
            $res = $stream->get(self::STREAM."/library/$library/videos", ['page' => $page, 'itemsPerPage' => 1000])->throw()->json();
            $out['video_count'] ??= (int) ($res['totalItems'] ?? 0);
            foreach ($res['items'] ?? [] as $video) {
                $storage += (int) ($video['storageSize'] ?? 0);
            }
            $more = count($res['items'] ?? []) >= 1000 && $page < 10 && ! $out['account_connected'];
            $page++;
        } while ($more);
        $out['storage_bytes'] = $storage;
        $out['storage_source'] = 'sum of video sizes';

        if (! $out['account_connected']) {
            return $out;
        }

        $account = $this->http()->withHeaders(['AccessKey' => (string) config('infra.bunny.account_api_key')]);
        $errors = [];

        try {
            $lib = $account->get(self::ACCOUNT."/videolibrary/$library")->throw()->json();
            $out['storage_bytes'] = isset($lib['StorageUsage']) ? (int) $lib['StorageUsage'] : $out['storage_bytes'];
            $out['storage_source'] = 'library StorageUsage';
            $out['library_traffic_bytes'] = isset($lib['TrafficUsage']) ? (int) $lib['TrafficUsage'] : null;
            $out['video_count'] = isset($lib['VideoCount']) ? (int) $lib['VideoCount'] : $out['video_count'];
        } catch (Throwable $e) {
            $errors['library'] = class_basename($e);
        }

        try {
            $stats = $account->get(self::ACCOUNT.'/statistics', [
                'dateFrom' => now()->startOfMonth()->utc()->format('Y-m-d\TH:i:s\Z'),
                'dateTo' => now()->utc()->format('Y-m-d\TH:i:s\Z'),
                'loadBandwidthUsed' => 'true',
                'loadRequestsServed' => 'true',
            ])->throw()->json();
            $out['bandwidth_month_bytes'] = isset($stats['TotalBandwidthUsed']) ? (int) $stats['TotalBandwidthUsed'] : null;
            $out['requests_month'] = isset($stats['TotalRequestsServed']) ? (int) $stats['TotalRequestsServed'] : null;
            $out['cache_hit_rate'] = isset($stats['CacheHitRate']) ? round((float) $stats['CacheHitRate'], 1) : null;
        } catch (Throwable $e) {
            $errors['statistics'] = class_basename($e);
        }

        try {
            $billing = $account->get(self::ACCOUNT.'/billing')->throw()->json();
            $breakdown = [];
            foreach ($billing as $k => $v) {
                if (str_starts_with((string) $k, 'MonthlyCharges') && is_numeric($v) && (float) $v > 0) {
                    $breakdown[substr((string) $k, strlen('MonthlyCharges'))] = round((float) $v, 4);
                }
            }
            $out['billing'] = [
                'currency' => 'USD',
                'this_month_charges' => isset($billing['ThisMonthCharges']) ? round((float) $billing['ThisMonthCharges'], 4) : null,
                'balance' => isset($billing['Balance']) ? round((float) $billing['Balance'], 2) : null,
                'breakdown' => $breakdown,
                'bandwidth_month_bytes' => isset($billing['MonthlyBandwidthUsed']) ? (int) $billing['MonthlyBandwidthUsed'] : null,
            ];
            $out['bandwidth_month_bytes'] ??= $out['billing']['bandwidth_month_bytes'];
        } catch (Throwable $e) {
            $errors['billing'] = class_basename($e);
        }

        if ($errors) {
            $out['partial_errors'] = $errors;
        }

        return $out;
    }
}
