<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Lets the CDN (and browsers) keep anonymous catalogue answers for a short time, so most requests never reach
 * PHP. Only plain GETs without a bearer token are marked public; anything personalised stays private.
 * The website fetches these through the CDN with ?lang=, so each language is cached under its own URL.
 */
class PublicCache
{
    public function handle(Request $request, Closure $next, string $seconds = '60'): Response
    {
        $response = $next($request);

        if ($request->isMethod('GET') && ! $request->bearerToken() && $response->getStatusCode() === 200
            && ! $response->headers->has('Set-Cookie')) {
            $ttl = max(1, (int) $seconds);
            $response->headers->set('Cache-Control', "public, max-age={$ttl}, s-maxage={$ttl}");
            // A browser must not reuse an anonymous copy for a later signed-in request.
            $response->setVary('Authorization', false);
        }

        return $response;
    }
}
