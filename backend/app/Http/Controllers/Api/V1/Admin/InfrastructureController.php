<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Services\Infra\InfraMetrics;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InfrastructureController extends Controller
{
    /** Super admin: server health, provider usage and the estimated monthly cost. ?refresh=1 skips the cache. */
    public function __invoke(Request $request, InfraMetrics $metrics): JsonResponse
    {
        return $this->ok($metrics->snapshot($request->boolean('refresh')))->header('Cache-Control', 'private, no-store');
    }
}
