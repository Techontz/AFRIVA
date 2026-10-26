<?php

namespace App\Http\Controllers\Api\V1\Studio;

use App\Http\Controllers\Api\V1\Concerns\ManagesDramas;
use App\Http\Controllers\Controller;
use App\Models\Drama;
use App\Services\AnalyticsService;
use App\Services\ReviewService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Company studio: strictly scoped to the authenticated user's company (other companies' dramas → 404). */
class DramaController extends Controller
{
    use ManagesDramas;

    protected function dramaScope(Request $request): Builder
    {
        return Drama::query()->where('company_id', $request->user()->company_id);
    }

    protected function forcedCompanyId(Request $request): ?int
    {
        return (int) $request->user()->company_id;
    }

    /** POST /studio/dramas/{drama}/submit {rights_declaration: true}: send the series / new episodes for review. */
    public function submit(Request $request, ReviewService $reviews, int $drama): JsonResponse
    {
        $model = $this->findDrama($request, $drama);
        $model = $reviews->submit($model, $request->user(), $request->boolean('rights_declaration'));

        return $this->show($request, $model->id);
    }

    /** GET /studio/dramas/{drama}/analytics?days=30 */
    public function analytics(Request $request, AnalyticsService $analytics, int $drama): JsonResponse
    {
        return $this->ok($analytics->dramaDetail($this->findDrama($request, $drama), $this->days($request)));
    }

    protected function days(Request $request): int
    {
        return in_array((int) $request->query('days'), [7, 30, 90], true) ? (int) $request->query('days') : 30;
    }

    protected function asStaff(): bool
    {
        return false;
    }
}
