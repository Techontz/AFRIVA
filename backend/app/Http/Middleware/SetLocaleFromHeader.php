<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Picks the API language from the Accept-Language header (en | sw, anything else falls back to en).
 * Handles values such as "sw-TZ,sw;q=0.9,en;q=0.8".
 */
class SetLocaleFromHeader
{
    public const SUPPORTED = ['en', 'sw'];

    public function handle(Request $request, Closure $next): Response
    {
        static::apply($request);

        $response = $next($request);
        $response->headers->set('Content-Language', app()->getLocale());
        // One combined Vary header (other middleware may already have added values such as Authorization).
        $vary = array_values(array_unique(array_merge($response->getVary(), ['Accept-Language'])));
        $response->headers->set('Vary', implode(', ', $vary));

        return $response;
    }

    /** Sets the app locale for this request; also used by the exception renderer for unmatched routes. */
    public static function apply(Request $request): string
    {
                $locale = static::SUPPORTED[0];
        // An explicit ?lang= wins: the website asks the CDN for one URL per language.
        $query = strtolower((string) $request->query('lang', ''));
        if (in_array($query, static::SUPPORTED, true)) {
            app()->setLocale($query);

            return $query;
        }
        if ($request->headers->has('Accept-Language')) {
            // Symfony matches "sw-TZ" to "sw" and returns the first supported locale when nothing matches.
            $locale = $request->getPreferredLanguage(static::SUPPORTED) ?? $locale;
        }
        app()->setLocale($locale);

        return $locale;
    }
}
