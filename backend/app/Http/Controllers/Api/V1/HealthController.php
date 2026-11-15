<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\BunnyStream;
use App\Support\MediaStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Str;
use Throwable;

/**
 * GET /api/v1/health: public, throttled, no secrets. 503 only when the database or the cache store fails
 * (status "down"); queue or storage problems give status "degraded" with HTTP 200 (deploy.sh rolls back on non-200).
 * Cheap enough for an uptime monitor every minute (no Bunny API call; cloud storage probed at most every 5 min).
 * /up (Laravel's bare liveness route) stays as it is.
 */
class HealthController extends Controller
{
    public function __invoke(BunnyStream $bunny): JsonResponse
    {
        $checks = [
            'database' => $this->check(function () {
                DB::select('select 1');

                return ['driver' => DB::connection()->getDriverName()];
            }),
            'cache' => $this->check(function () {
                $key = 'health:'.Str::random(12);
                Cache::put($key, 'ok', 10);
                $ok = Cache::get($key) === 'ok';
                Cache::forget($key);
                if (! $ok) {
                    throw new \RuntimeException('round trip failed');
                }

                return ['store' => (string) config('cache.default')];
            }),
            'queue' => $this->check(function () {
                $connection = (string) config('queue.default');
                if (config("queue.connections.$connection.driver") === 'redis') {
                    Redis::connection(config("queue.connections.$connection.connection", 'default'))->ping();
                }

                return ['connection' => $connection];
            }),
            'storage' => $this->check(fn () => $this->storage()),
        ];

        // Only the database and the cache store are hard failures (503). Queue and storage problems are reported
        // as "degraded" with HTTP 200, so a deploy before the R2 migration (or with R2 down) never rolls back.
        $down = ! $checks['database']['ok'] || ! $checks['cache']['ok'];
        $degraded = ! $down && collect($checks)->contains(fn ($c) => ! $c['ok']);

        return response()->json([
            'data' => [
                'status' => $down ? 'down' : ($degraded ? 'degraded' : 'ok'),
                'checks' => $checks,
                'bunny_configured' => $bunny->enabled(),
                'version' => config('app.version'),
                'commit' => config('app.commit'),
                'environment' => app()->environment(),
                'time' => now()->toIso8601String(),
            ],
        ], $down ? 503 : 200, ['Cache-Control' => 'no-store']);
    }

    /** @return array<string,mixed> */
    protected function storage(): array
    {
        $name = MediaStorage::mediaDiskName();
        if (MediaStorage::isLocal($name)) {
            $root = (string) config("filesystems.disks.$name.root");
            if (! is_dir($root) || ! is_writable($root)) {
                throw new \RuntimeException('not writable');
            }

            return ['disk' => $name, 'driver' => 'local'];
        }

        // Cloud disk: one tiny write at most every 5 minutes (each write is a billable operation).
        $ok = Cache::remember("health:storage:$name", 300, function () {
            try {
                return MediaStorage::media()->put('.health/probe.txt', now()->toIso8601String()) ? 1 : 0;
            } catch (Throwable) {
                return 0;
            }
        });
        if (! $ok) {
            Cache::forget("health:storage:$name");
            throw new \RuntimeException('not writable');
        }

        return ['disk' => $name, 'driver' => (string) config("filesystems.disks.$name.driver")];
    }

    /** @return array<string,mixed> */
    protected function check(callable $fn): array
    {
        $start = microtime(true);
        try {
            $details = $fn();

            return ['ok' => true] + $details + ['ms' => (int) round((microtime(true) - $start) * 1000)];
        } catch (Throwable $e) {
            report($e);

            // Generic error only: exception messages may contain hosts or credentials.
            return ['ok' => false, 'error' => class_basename($e), 'ms' => (int) round((microtime(true) - $start) * 1000)];
        }
    }
}
