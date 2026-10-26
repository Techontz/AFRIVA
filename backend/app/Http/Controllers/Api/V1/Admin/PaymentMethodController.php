<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdatePaymentMethodRequest;
use App\Http\Resources\PaymentMethodResource;
use App\Models\AuditLog;
use App\Models\PaymentMethod;
use Illuminate\Http\JsonResponse;

class PaymentMethodController extends Controller
{
    public function index(): JsonResponse
    {
        return $this->ok(PaymentMethod::orderBy('sort_order')->get()
            ->map(fn ($m) => (new PaymentMethodResource($m))->withConfig()));
    }

    public function show(PaymentMethod $paymentMethod): JsonResponse
    {
        return $this->ok((new PaymentMethodResource($paymentMethod))->withConfig());
    }

    public function update(UpdatePaymentMethodRequest $request, PaymentMethod $paymentMethod): JsonResponse
    {
        $data = $request->validated();
        if (($data['is_integrated'] ?? false) && ! $paymentMethod->is_integrated) {
            $data['tested_at'] = now();
        }
        $paymentMethod->update($data);
        $changes = AuditLog::diff($paymentMethod, ['name', 'is_enabled', 'is_integrated', 'fee_percent']);
        if ($changes || array_key_exists('config', $data)) {
            AuditLog::record('payment_method.update', $paymentMethod, $changes + (array_key_exists('config', $data) ? ['config' => 'imebadilishwa'] : []), $paymentMethod->name);
        }

        return $this->ok((new PaymentMethodResource($paymentMethod->fresh()))->withConfig());
    }
}
