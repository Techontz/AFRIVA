<?php

namespace App\Providers;

use App\Models\Category;
use App\Models\Company;
use App\Models\Drama;
use App\Models\Episode;
use App\Models\PaymentMethod;
use App\Models\Plan;
use App\Models\Tag;
use App\Support\CatalogCache;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Middleware\TrustProxies;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        if ($proxies = config('app.trusted_proxies')) {
            TrustProxies::at($proxies === '*' ? '*' : array_map('trim', explode(',', $proxies)));
        }

        // Default limit for every /api route; auth routes add their own stricter throttles.
        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(240)->by($request->user()?->id ?: $request->ip()));

        // Public catalogue responses are cached for a few minutes; any admin/studio change invalidates them.
        // (View counters are bumped with query-builder increments, which deliberately do not fire these events.)
        foreach ([Drama::class, Episode::class, Category::class, Tag::class, Plan::class, PaymentMethod::class, Company::class] as $model) {
            $model::saved(fn () => CatalogCache::flush());
            $model::deleted(fn () => CatalogCache::flush());
        }
    }
}
