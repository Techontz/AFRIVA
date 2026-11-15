<?php

namespace App\Services\Infra\Providers;

/** CPU load, memory and disk of the machine (or container) PHP runs on. No external calls. */
class ServerProvider extends Provider
{
    public function key(): string
    {
        return 'server';
    }

    public function source(): string
    {
        return 'This server';
    }

    public function collect(): array
    {
        $load = function_exists('sys_getloadavg') ? sys_getloadavg() : false;
        $cores = $this->cpuCores();
        $memory = $this->memory();
        $path = base_path();
        $diskTotal = @disk_total_space($path) ?: null;
        $diskFree = @disk_free_space($path) ?: null;

        return [
            'load' => $load ? array_map(fn ($v) => round((float) $v, 2), $load) : null,
            'cpu_cores' => $cores,
            'load_percent' => $load && $cores ? round($load[0] / $cores * 100, 1) : null,
            'memory_total_bytes' => $memory['total'] ?? null,
            'memory_available_bytes' => $memory['available'] ?? null,
            'memory_used_percent' => isset($memory['total'], $memory['available']) && $memory['total'] > 0
                ? round(($memory['total'] - $memory['available']) / $memory['total'] * 100, 1) : null,
            'disk_total_bytes' => $diskTotal ? (int) $diskTotal : null,
            'disk_free_bytes' => $diskFree ? (int) $diskFree : null,
            'disk_used_percent' => $diskTotal && $diskFree !== null ? round(($diskTotal - $diskFree) / $diskTotal * 100, 1) : null,
            'php_version' => PHP_VERSION,
            'os' => PHP_OS_FAMILY,
        ];
    }

    protected function cpuCores(): ?int
    {
        if (is_readable('/proc/cpuinfo')) {
            $count = preg_match_all('/^processor\s*:/m', (string) @file_get_contents('/proc/cpuinfo'));

            return $count ?: null;
        }

        return null;
    }

    /** @return array{total?:int,available?:int} Bytes, from /proc/meminfo when available (Linux). */
    protected function memory(): array
    {
        if (! is_readable('/proc/meminfo')) {
            return [];
        }
        $out = [];
        foreach (explode("\n", (string) @file_get_contents('/proc/meminfo')) as $line) {
            if (preg_match('/^(MemTotal|MemAvailable):\s+(\d+)\s*kB/', $line, $m)) {
                $out[$m[1] === 'MemTotal' ? 'total' : 'available'] = (int) $m[2] * 1024;
            }
        }

        return $out;
    }
}
