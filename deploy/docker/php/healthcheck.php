#!/usr/bin/env php
<?php
/*
 * Afriva container health check for the worker and scheduler roles.
 *
 *   afriva-healthcheck worker     PID 1 is "artisan queue:work" and Redis answers PING
 *   afriva-healthcheck scheduler  PID 1 is "artisan schedule:work"
 *
 * Reads connection settings from bootstrap/cache/config.php (written by "php artisan optimize" in the
 * entrypoint), so it does not boot Laravel and costs a few milliseconds. The app (php-fpm) role is
 * checked with cgi-fcgi against /fpm-ping instead (see docker-compose.prod.yml).
 */

$role = $argv[1] ?? '';
$needles = ['worker' => 'queue:work', 'scheduler' => 'schedule:work'];

if (! isset($needles[$role])) {
    fwrite(STDERR, "usage: afriva-healthcheck worker|scheduler\n");
    exit(2);
}

$cmdline = str_replace("\0", ' ', (string) @file_get_contents('/proc/1/cmdline'));
if (! str_contains($cmdline, $needles[$role])) {
    fwrite(STDERR, "PID 1 is not {$needles[$role]}: {$cmdline}\n");
    exit(1);
}

if ($role === 'worker') {
    $config = @include '/var/www/html/bootstrap/cache/config.php';
    $redis = is_array($config) ? ($config['database']['redis']['default'] ?? null) : null;
    if (is_array($redis) && class_exists(Redis::class)) {
        try {
            $client = new Redis();
            $client->connect((string) ($redis['host'] ?? 'redis'), (int) ($redis['port'] ?? 6379), 2.0);
            $password = $redis['password'] ?? null;
            if ($password !== null && $password !== '') {
                $username = $redis['username'] ?? null;
                $client->auth($username ? [$username, $password] : $password);
            }
            $pong = $client->ping();
            if ($pong !== true && $pong !== '+PONG' && $pong !== 'PONG') {
                fwrite(STDERR, "Redis did not answer PING\n");
                exit(1);
            }
        } catch (Throwable $e) {
            fwrite(STDERR, 'Redis unreachable: '.$e->getMessage()."\n");
            exit(1);
        }
    }
}

exit(0);
