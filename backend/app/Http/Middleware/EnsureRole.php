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
            throw new ApiException('Unauthenticated.', 'unauthenticated', 401);
        }
        if ($user->status !== 'active') {
            throw new ApiException('Your account is suspended.', 'account_suspended', 403);
        }
        if (! in_array($user->role, $roles, true)) {
            throw new ApiException('You do not have permission to access this resource.', 'forbidden', 403);
        }
        if ($user->role === 'company' && ! $user->company_id) {
            throw new ApiException('No company is linked to this account.', 'no_company', 403);
        }

        return $next($request);
    }
}
