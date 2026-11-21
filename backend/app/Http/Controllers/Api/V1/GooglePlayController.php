<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\PaymentResource;
use App\Models\Payment;
use App\Models\Plan;
use App\Services\GooglePlayPurchases;
use App\Services\PaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class GooglePlayController extends Controller
{
    /**
     * POST /payments/google-play {product_id, purchase_token}
     * The Play Store app calls this after Google Play confirms a purchase; the token is checked with
     * Google before the plan is activated. Safe to call again with the same token (returns the same payment).
     */
    public function store(Request $request, GooglePlayPurchases $play, PaymentService $payments): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'string', 'max:100'],
            'purchase_token' => ['required', 'string', 'max:4096'],
        ]);
        $plan = Plan::where('play_product_id', $data['product_id'])->first();
        if (! $plan) {
            throw new ApiException(__('api.not_found'), 'not_found', 404);
        }
        $user = $request->user();
        $key = hash('sha256', $data['purchase_token']);

        $existing = Payment::where('payment_method_code', 'google_play')->where('provider_reference', $key)->first();
        if ($existing) {
            if ($existing->user_id !== $user->id) {
                throw new ApiException(__('api.play_purchase_invalid'), 'play_purchase_invalid', 422);
            }

            return $this->ok(['payment' => new PaymentResource($existing->load('plan'))]);
        }

        $purchase = $play->verify($data['product_id'], $data['purchase_token']);
        if (! $purchase) {
            throw new ApiException(__('api.play_purchase_invalid'), 'play_purchase_invalid', 422);
        }

        $payment = DB::transaction(function () use ($user, $plan, $key, $purchase, $data) {
            return Payment::create([
                'user_id' => $user->id,
                'plan_id' => $plan->id,
                'payment_method_code' => 'google_play',
                'reference' => Payment::newReference(),
                'amount' => $plan->price,
                'currency' => $plan->currency ?: 'TZS',
                'status' => 'pending',
                'provider_reference' => $key,
                'meta' => ['driver' => 'google_play', 'plan_type' => $plan->type, 'order_id' => $purchase['orderId'], 'product_id' => $data['product_id']],
            ]);
        });
        $payment = $payments->fulfill($payment);

        return $this->ok(['payment' => new PaymentResource($payment->fresh(['plan']))], null, 201);
    }
}
