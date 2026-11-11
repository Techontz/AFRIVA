<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\DramaResource;
use App\Http\Resources\PaymentResource;
use App\Models\Company;
use App\Models\Drama;
use App\Models\Payment;
use App\Models\PaymentMethod;
use App\Models\Plan;
use App\Models\Subscription;
use App\Models\User;
use App\Services\StatsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function __invoke(StatsService $stats): JsonResponse
    {
        $success = fn () => Payment::where('status', 'success');
        $today = now()->startOfDay();
        $monthStart = now()->startOfMonth();

        $from30 = now()->subDays(29)->toDateString();
        $dramaViews30 = DB::table('episode_views')->where('viewed_on', '>=', $from30)
            ->select('drama_id', DB::raw('COUNT(*) as c'))->groupBy('drama_id')
            ->orderByDesc('c')->limit(10)->pluck('c', 'drama_id')->all();
        $topDramas = Drama::with(['categories', 'tags', 'company'])->whereIn('id', array_keys($dramaViews30))->get()
            ->sortByDesc(fn ($d) => $dramaViews30[$d->id] ?? 0)->values()
            ->each(fn ($d, $i) => $d->setAttribute('period_views', $dramaViews30[$d->id] ?? 0)->setAttribute('rank', $i + 1));
        if ($topDramas->isEmpty()) {
            $topDramas = Drama::with(['categories', 'tags', 'company'])->orderByDesc('views')->limit(10)->get();
        }

        $methodNames = PaymentMethod::pluck('name', 'code');
        $byMethod = Payment::where('status', 'success')
            ->select('payment_method_code', DB::raw('SUM(amount) as total'), DB::raw('COUNT(*) as cnt'))
            ->groupBy('payment_method_code')->orderByDesc('total')->get()
            ->map(fn ($r) => [
                'method' => $r->payment_method_code,
                'name' => $methodNames[$r->payment_method_code] ?? $r->payment_method_code,
                'value' => (int) $r->total,
                'count' => (int) $r->cnt,
            ])->values();

        $planNames = Plan::pluck('type', 'id');
        $byPlanType = Payment::where('status', 'success')->whereNotNull('plan_id')
            ->select('plan_id', DB::raw('SUM(amount) as total'))->groupBy('plan_id')->get()
            ->groupBy(fn ($r) => $planNames[$r->plan_id] ?? 'other')
            ->map(fn ($g, $type) => ['type' => $type, 'value' => (int) $g->sum('total')])->values();

        return $this->ok([
            'totals' => [
                'revenue' => (int) $success()->sum('amount'),
                'revenue_today' => (int) $success()->where('paid_at', '>=', $today)->sum('amount'),
                'revenue_month' => (int) $success()->where('paid_at', '>=', $monthStart)->sum('amount'),
                'users' => User::count(),
                'viewers' => User::where('role', 'viewer')->count(),
                'new_users_30d' => User::where('created_at', '>=', now()->subDays(30))->count(),
                'active_subscribers' => Subscription::timeBased()->current()->distinct()->count('user_id'),
                'companies' => Company::count(),
                'dramas' => Drama::count(),
                'published_dramas' => Drama::where('status', 'published')->count(),
                'episodes' => DB::table('episodes')->count(),
                'views' => (int) Drama::sum('views'),
                'views_today' => DB::table('episode_views')->where('viewed_on', now()->toDateString())->count(),
                'pending_payments' => Payment::where('status', 'pending')->count(),
                'company_earnings' => (int) DB::table('company_earnings')->sum('amount'),
            ],
            'revenue_chart' => $stats->revenueChart(30),
            'views_chart' => $stats->viewsChart(null, 30),
            'top_dramas' => DramaResource::collection($topDramas),
            'recent_payments' => PaymentResource::collection(Payment::with(['plan', 'user'])->latest()->limit(10)->get()),
            'revenue_by_method' => $byMethod,
            'revenue_by_plan_type' => $byPlanType,
        ]);
    }
}
