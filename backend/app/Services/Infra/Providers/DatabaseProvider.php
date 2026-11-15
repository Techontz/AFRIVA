<?php

namespace App\Services\Infra\Providers;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Throwable;

/** Database size (MySQL/MariaDB via information_schema, SQLite file size) and Redis memory when Redis is the cache. */
class DatabaseProvider extends Provider
{
    public function key(): string
    {
        return 'database';
    }

    public function source(): string
    {
        return 'Database and Redis';
    }

    public function collect(): array
    {
        $driver = DB::connection()->getDriverName();
        $size = null;
        $tables = null;
        if (in_array($driver, ['mysql', 'mariadb'], true)) {
            $row = DB::selectOne('SELECT COALESCE(SUM(data_length + index_length), 0) AS bytes, COUNT(*) AS tables_count
                FROM information_schema.tables WHERE table_schema = DATABASE()');
            $size = (int) ($row->bytes ?? 0);
            $tables = (int) ($row->tables_count ?? 0);
        } elseif ($driver === 'sqlite') {
            $file = (string) DB::connection()->getConfig('database');
            $size = $file !== ':memory:' && is_file($file) ? (int) filesize($file) : null;
        }

        return [
            'driver' => $driver,
            'size_bytes' => $size,
            'tables' => $tables,
            'redis' => $this->redis(),
        ];
    }

    /** @return array<string,mixed> */
    protected function redis(): array
    {
        $store = (string) config('cache.default');
        if (config("cache.stores.$store.driver") !== 'redis') {
            return ['in_use' => false];
        }
        try {
            $info = Redis::connection(config("cache.stores.$store.connection", 'cache'))->info('memory');
            // phpredis returns a flat array, predis nests it under "Memory".
            $info = is_array($info['Memory'] ?? null) ? $info['Memory'] : $info;

            return [
                'in_use' => true,
                'ok' => true,
                'used_memory_bytes' => isset($info['used_memory']) ? (int) $info['used_memory'] : null,
                'max_memory_bytes' => ! empty($info['maxmemory']) ? (int) $info['maxmemory'] : null,
            ];
        } catch (Throwable $e) {
            return ['in_use' => true, 'ok' => false, 'error' => class_basename($e)];
        }
    }
}
