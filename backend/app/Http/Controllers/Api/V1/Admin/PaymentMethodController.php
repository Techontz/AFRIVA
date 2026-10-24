<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdatePaymentMethodRequest;
use App\Http\Resources\PaymentMethodResource;
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
        $paymentMethod->update($request->validated());

        return $this->ok((new PaymentMethodResource($paymentMethod->fresh()))->withConfig());
    }
}
