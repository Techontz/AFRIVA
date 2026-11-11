<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Usage: ->middleware('role:super_admin') or 'role:company' (comma-separate for several).
 */
class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user) {
            throw new ApiException(__('api.unauthenticated'), 'unauthenticated', 401);
        }
        if ($user->status === 'pending') {
            throw new ApiException(__('api.account_pending'), 'account_pending', 403);
        }
        if ($user->status !== 'active') {
            throw new ApiException(__('api.account_suspended'), 'account_suspended', 403);
        }
        if (! in_array($user->role, $roles, true)) {
            throw new ApiException(__('api.no_permission'), 'forbidden', 403);
        }
        if ($user->role === 'company' && ! $user->company_id) {
            throw new ApiException(__('api.no_company'), 'no_company', 403);
        }
        // Posting is only possible once Afriva has approved the studio.
        if ($user->role === 'company' && $user->company?->status !== 'active') {
            throw new ApiException(__('api.company_not_approved'), 'company_not_approved', 403);
        }

        return $next($request);
    }
}
