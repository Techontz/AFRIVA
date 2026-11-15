<?php

namespace App\Services\Infra\Providers;

use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;

/**
 * One section of the infrastructure snapshot. A provider is only queried when configured() is true (its env
 * token exists); otherwise the dashboard shows "Not connected" with the env variables from requiredEnv().
 */
abstract class Provider
{
    /** Section key in the snapshot, e.g. "hetzner". */
    abstract public function key(): string;

    /** Where the figures come from, e.g. "Hetzner Cloud API". */
    abstract public function source(): string;

    /** @return array<string,mixed> The section's figures. May throw: InfraMetrics records the failure. */
    abstract public function collect(): array;

    public function configured(): bool
    {
        return true;
    }

    /** @return array<int,string> Env variables that connect this provider. */
    public function requiredEnv(): array
    {
        return [];
    }

    protected function http(): PendingRequest
    {
        return Http::timeout((int) config('infra.http_timeout', 8))->connectTimeout(5)->acceptJson();
    }

    protected static function gb(int|float|null $bytes): ?float
    {
        return $bytes === null ? null : round($bytes / 1_000_000_000, 3);
    }
}
