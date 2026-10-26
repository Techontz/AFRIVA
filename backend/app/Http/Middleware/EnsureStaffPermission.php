<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Usage: ->middleware('staff:content') (comma-separate for "any of"). Runs after role:super_admin.
 */
class EnsureStaffPermission
{
    public function handle(Request $request, Closure $next, string ...$permissions): Response
    {
        $user = $request->user();
        foreach ($permissions as $permission) {
            if ($user?->hasPermission($permission)) {
                return $next($request);
            }
        }

        throw new ApiException('Huna ruhusa ya kufanya kitendo hiki.', 'forbidden', 403);
    }
}
