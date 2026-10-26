<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\PayoutRequest;
use App\Http\Requests\SettingsRequest;
use App\Http\Requests\UpdatePayoutRequest;
use App\Http\Resources\CoinTransactionResource;
use App\Http\Resources\PaymentResource;
use App\Http\Resources\PayoutResource;
use App\Models\AuditLog;
use App\Models\CoinTransaction;
use App\Models\Payment;
use App\Models\Payout;
use App\Models\Setting;
use App\Services\PaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Payments list, payouts and platform settings. */
class FinanceController extends Controller
{
    public function payments(Request $request): JsonResponse
    {
        $q = Payment::query()->with(['plan', 'user']);
        foreach (['status', 'user_id', 'plan_id'] as $f) {
            if ($v = $request->query($f)) {
                $q->where($f, $v);
            }
        }
        if ($m = ($request->query('method') ?? $request->query('payment_method'))) {
            $q->where('payment_method_code', $m);
        }
        if ($s = trim((string) ($request->query('q') ?? $request->query('search') ?? ''))) {
            $q->where(fn ($w) => $w->where('reference', 'like', "%{$s}%")->orWhere('phone', 'like', "%{$s}%")
                ->orWhereHas('user', fn ($u) => $u->where('name', 'like', "%{$s}%")->orWhere('email', 'like', "%{$s}%")));
        }
        if ($from = $request->query('date_from')) {
            $q->where('created_at', '>=', $from.' 00:00:00');
        }
        if ($to = $request->query('date_to')) {
            $q->where('created_at', '<=', $to.' 23:59:59');
        }

        $summary = (clone $q)->reorder()->where('status', 'success')->sum('amount');

        return $this->paginated($q->latest()->paginate($this->perPage(25)), PaymentResource::class, [
            'total_success_amount' => (int) $summary,
        ]);
    }

    /** GET /admin/payments/{payment}: detail with refunds and receipt. */
    public function showPayment(Payment $payment, PaymentService $payments): JsonResponse
    {
        $payment->load(['plan', 'user', 'refunds.processor']);

        return $this->ok([
            'payment' => new PaymentResource($payment),
            'refunds' => $payment->refunds->map(fn ($r) => [
                'id' => $r->id, 'amount' => (int) $r->amount, 'reason' => $r->reason, 'status' => $r->status,
                'processed_by' => $r->processor?->name, 'created_at' => $r->created_at?->toIso8601String(),
            ])->values(),
            'receipt' => in_array($payment->status, ['success', 'refunded'], true) ? $payments->receipt($payment) : null,
            'net_amount' => $payment->netAmount(),
            'meta' => $payment->meta,
        ]);
    }

    /** POST /admin/payments/{payment}/refund {amount?, reason} */
    public function refund(Request $request, Payment $payment, PaymentService $payments): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['nullable', 'integer', 'min:1'],
            'reason' => ['required', 'string', 'max:190'],
        ]);
        $payments->refund($payment, $request->user(), $data['amount'] ?? null, $data['reason']);

        return $this->showPayment($payment->fresh(), $payments);
    }

    /** GET /admin/coin-transactions?user_id=&type= */
    public function coinTransactions(Request $request): JsonResponse
    {
        $q = CoinTransaction::query()->with(['episode.drama', 'user:id,name,email,phone']);
        if ($u = $request->query('user_id')) {
            $q->where('user_id', $u);
        }
        if ($t = $request->query('type')) {
            $q->where('type', $t);
        }

        return $this->paginated($q->latest('id')->paginate($this->perPage(50)), CoinTransactionResource::class);
    }

    public function payouts(Request $request): JsonResponse
    {
        $q = Payout::query()->with('company');
        if ($c = $request->query('company_id')) {
            $q->where('company_id', $c);
        }
        if ($s = $request->query('status')) {
            $q->where('status', $s);
        }

        return $this->paginated($q->latest()->paginate($this->perPage(25)), PayoutResource::class);
    }

    public function storePayout(PayoutRequest $request): JsonResponse
    {
        $data = $request->validated();
        $data['status'] ??= 'pending';
        if ($data['status'] === 'paid') {
            $data['paid_at'] = now();
        }
        $data['reference'] ??= 'PO-'.now()->format('ymdHis');
        $payout = Payout::create($data);
        AuditLog::record('payout.create', $payout, $payout->only(['company_id', 'amount', 'status']), 'TSh '.number_format($payout->amount));

        return $this->ok(new PayoutResource($payout->load('company')), null, 201);
    }

    public function updatePayout(UpdatePayoutRequest $request, Payout $payout): JsonResponse
    {
        $data = $request->validated();
        if (($data['status'] ?? null) === 'paid' && $payout->status !== 'paid') {
            $data['paid_at'] = now();
        }
        if (($data['status'] ?? null) === 'pending') {
            $data['paid_at'] = null;
        }
        $payout->update($data);
        if ($diff = AuditLog::diff($payout, ['amount', 'status', 'reference'])) {
            AuditLog::record('payout.update', $payout, $diff, 'TSh '.number_format($payout->amount));
        }

        return $this->ok(new PayoutResource($payout->load('company')));
    }

    public function settings(): JsonResponse
    {
        return $this->ok(Setting::allAsArray());
    }

    public function updateSettings(SettingsRequest $request): JsonResponse
    {
        $values = $request->input('settings', $request->except(['settings', '_method', '_token']));
        $before = Setting::allAsArray();
        $changed = [];
        foreach ((array) $values as $key => $value) {
            if (is_string($key) && preg_match('/^[a-z0-9_.]{1,100}$/', $key)) {
                Setting::put($key, $value);
                if ((string) ($before[$key] ?? '') !== (string) (is_scalar($value) ? $value : json_encode($value))) {
                    $changed[$key] = ['from' => $before[$key] ?? null, 'to' => $value];
                }
            }
        }
        if ($changed) {
            AuditLog::record('settings.update', null, $changed, implode(', ', array_keys($changed)));
        }

        return $this->ok(Setting::allAsArray());
    }
}
