<?php

namespace App\Http\Controllers\Api\V1\Studio;

use App\Http\Controllers\Controller;
use App\Http\Requests\StudioProfileRequest;
use App\Http\Resources\CompanyEarningResource;
use App\Http\Resources\CompanyResource;
use App\Http\Resources\PayoutResource;
use App\Http\Resources\UserResource;
use App\Models\Company;
use App\Models\CompanyEarning;
use App\Models\Payout;
use App\Services\ContentService;
use App\Services\StatsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Company studio: dashboard, earnings, payouts, profile — always scoped to the user's company. */
class StudioController extends Controller
{
    protected function company(Request $request): Company
    {
        return Company::findOrFail($request->user()->company_id);
    }

    public function dashboard(Request $request, StatsService $stats): JsonResponse
    {
        return $this->ok($stats->companyStats($this->company($request)));
    }

    public function earnings(Request $request, StatsService $stats): JsonResponse
    {
        $company = $this->company($request);
        $q = CompanyEarning::query()->with('drama')->where('company_id', $company->id);
        if ($s = $request->query('source')) {
            $q->where('source', $s);
        }
        if ($d = $request->query('drama_id')) {
            $q->where('drama_id', $d);
        }
        if ($from = $request->query('date_from')) {
            $q->where('period_date', '>=', $from);
        }
        if ($to = $request->query('date_to')) {
            $q->where('period_date', '<=', $to);
        }

        $total = (int) CompanyEarning::where('company_id', $company->id)->sum('amount');
        $month = (int) CompanyEarning::where('company_id', $company->id)->where('period_date', '>=', now()->startOfMonth()->toDateString())->sum('amount');
        $paid = (int) Payout::where('company_id', $company->id)->where('status', 'paid')->sum('amount');
        $bySource = CompanyEarning::where('company_id', $company->id)
            ->select('source', DB::raw('SUM(amount) as total'))->groupBy('source')->pluck('total', 'source')
            ->map(fn ($v) => (int) $v)->all();

        return $this->paginated($q->orderByDesc('period_date')->orderByDesc('id')->paginate($this->perPage(30)), CompanyEarningResource::class, [
            'summary' => [
                'total' => $total,
                'month' => $month,
                'paid_out' => $paid,
                'pending_payout' => max(0, $total - $paid),
                'by_source' => (object) $bySource,
                'revenue_share_percent' => (float) $company->revenue_share_percent,
            ],
            'earnings_chart' => $stats->earningsChart($company->id),
        ]);
    }

    public function payouts(Request $request): JsonResponse
    {
        $company = $this->company($request);
        $q = Payout::where('company_id', $company->id)->latest();

        return $this->paginated($q->paginate($this->perPage(30)), PayoutResource::class, [
            'total_paid' => (int) Payout::where('company_id', $company->id)->where('status', 'paid')->sum('amount'),
            'total_pending' => (int) Payout::where('company_id', $company->id)->where('status', 'pending')->sum('amount'),
        ]);
    }

    public function profile(Request $request): JsonResponse
    {
        $company = $this->company($request)->loadCount('dramas');

        return $this->ok([
            'company' => new CompanyResource($company),
            'user' => new UserResource($request->user()->load('company')),
        ]);
    }

    public function updateProfile(StudioProfileRequest $request, ContentService $content): JsonResponse
    {
        $company = $this->company($request);
        $data = $request->validated();
        $company->fill(collect($data)->except('logo')->all());
        if (isset($data['country'])) {
            $company->country = strtoupper($data['country']);
        }
        if ($request->hasFile('logo')) {
            $company->logo_url = $content->storeFile($request->file('logo'), 'logos');
        }
        $company->save();

        return $this->ok([
            'company' => new CompanyResource($company->loadCount('dramas')),
            'user' => new UserResource($request->user()->fresh('company')),
        ]);
    }
}
