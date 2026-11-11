<?php

namespace App\Support;

use Closure;
use Illuminate\Support\Facades\Cache;

/**
 * Short lived cache for public catalogue data (home, rankings, categories, plans, payment methods, drama pages).
 *
 * Every key embeds a version number; flush() bumps the version so all catalogue entries are invalidated at
 * once (old entries simply expire). flush() runs automatically when a Drama, Episode, Category, Tag, Plan,
 * PaymentMethod or Company is saved or deleted (see AppServiceProvider) and after pivot syncs.
 */
class CatalogCache
{
    public const TTL = 300;

    protected const VERSION_KEY = 'catalog:version';

    public static function remember(string $key, Closure $resolver, int $ttl = self::TTL): mixed
    {
        return Cache::remember('catalog:'.static::version().':'.$key, $ttl, $resolver);
    }

    public static function flush(): void
    {
        Cache::forever(static::VERSION_KEY, static::version() + 1);
        Viewer::forget(static::VERSION_KEY);
    }

    protected static function version(): int
    {
        return (int) Viewer::remember(static::VERSION_KEY, fn () => Cache::get(static::VERSION_KEY, 1));
    }
}
