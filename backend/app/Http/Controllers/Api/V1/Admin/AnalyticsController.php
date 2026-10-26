<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Drama;
use App\Models\OperatingCost;
use App\Services\AnalyticsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

/** Analytics (scope §06) and the monthly operating costs used for net revenue after costs. */
class AnalyticsController extends Controller
{
    public function __construct(protected AnalyticsService $analytics) {}

    protected function days(Request $request): int
    {
        return in_array((int) $request->query('days'), [7, 30, 90, 365], true) ? (int) $request->query('days') : 30;
    }

    public function overview(Request $request): JsonResponse
    {
        return $this->ok($this->analytics->overview($this->days($request)));
    }

    public function drama(Request $request, int $drama): JsonResponse
    {
        return $this->ok($this->analytics->dramaDetail(Drama::findOrFail($drama), $this->days($request)));
    }

    public function costs(Request $request): JsonResponse
    {
        $q = OperatingCost::with('creator:id,name')->orderByDesc('period')->orderBy('category');

        return $this->ok($q->limit(240)->get()->map(fn (OperatingCost $c) => [
            'id' => $c->id, 'period' => $c->period, 'category' => $c->category, 'amount' => (int) $c->amount,
            'notes' => $c->notes, 'created_by' => $c->creator?->name, 'created_at' => $c->created_at?->toIso8601String(),
        ]));
    }

    public function storeCost(Request $request): JsonResponse
    {
        $data = $request->validate([
            'period' => ['required', 'date_format:Y-m'],
            'category' => ['required', Rule::in(OperatingCost::CATEGORIES)],
            'amount' => ['required', 'integer', 'min:0'],
            'notes' => ['nullable', 'string', 'max:190'],
        ]);
        $cost = OperatingCost::create([
            'period' => Carbon::createFromFormat('Y-m', $data['period'])->startOfMonth()->toDateString(),
            'category' => $data['category'],
            'amount' => $data['amount'],
            'notes' => $data['notes'] ?? null,
            'created_by' => $request->user()->id,
        ]);
        AuditLog::record('cost.create', $cost, $cost->only(['period', 'category', 'amount']), "{$cost->category} {$cost->period}");

        return $this->ok($cost, null, 201);
    }

    public function destroyCost(int $cost): JsonResponse
    {
        $model = OperatingCost::findOrFail($cost);
        $model->delete();
        AuditLog::record('cost.delete', $model, $model->only(['period', 'category', 'amount']));

        return $this->ok(['deleted' => true]);
    }
}
