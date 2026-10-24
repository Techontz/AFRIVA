<?php

namespace App\Http\Controllers\Api\V1\Studio;

use App\Http\Controllers\Api\V1\Concerns\ManagesDramas;
use App\Http\Controllers\Controller;
use App\Models\Drama;
use Illuminate\Database\Eloquent\Builder;
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
}
