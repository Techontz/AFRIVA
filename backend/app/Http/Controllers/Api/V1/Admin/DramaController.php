<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\Concerns\ManagesDramas;
use App\Http\Controllers\Controller;
use App\Models\Drama;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;

/** Super admin: all dramas of all companies. */
class DramaController extends Controller
{
    use ManagesDramas;

    protected function dramaScope(Request $request): Builder
    {
        return Drama::query();
    }

    protected function forcedCompanyId(Request $request): ?int
    {
        return null;
    }
}
