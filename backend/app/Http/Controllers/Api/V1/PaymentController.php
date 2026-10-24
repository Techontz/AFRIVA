<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\CheckoutRequest;
use App\Http\Resources\PaymentResource;
use App\Http\Resources\SubscriptionResource;
use App\Models\Payment;
use App\Models\PaymentMethod;
use App\Models\Plan;
use App\Payments\PaymentManager;
use App\Services\PaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;

class PaymentController extends Controller
{
    public function __construct(protected PaymentService $payments, protected PaymentManager $manager) {}

    /** POST /checkout */
    public function checkout(CheckoutRequest $request): JsonResponse
    {
        $plan = Plan::findOrFail($request->integer('plan_id'));
        $method = PaymentMethod::where('code', $request->input('payment_method'))->firstOrFail();

        if ($method->type === 'mobile_money' && ! $request->filled('phone') && ! $request->user()->phone) {
            throw ValidationException::withMessages(['phone' => ['A phone number is required for mobile money payments.']]);
        }
        $phone = $request->input('phone') ?: ($method->type === 'mobile_money' ? $request->user()->phone : null);

        [$payment, $response] = $this->payments->checkout($request->user(), $plan, $method->code, $phone, [
            'card' => null, // card details are never stored or forwarded by this API
        ]);

        $message = match ($payment->status) {
            'success' => 'Payment successful. Enjoy Afriva!',
            'failed' => $response->message ?: 'Payment failed.',
            default => 'Pending — payment provider not yet connected.',
        };
        if ($payment->status === 'pending' && $response->message && $response->message !== 'Provider not yet connected') {
            $message = $response->message;
        }

        $data = [
            'payment' => new PaymentResource($payment),
            'message' => $message,
            'next_action' => $payment->status === 'pending' ? $response->nextAction : 'none',
        ];
        if ($response->redirectUrl) {
            $data['redirect_url'] = $response->redirectUrl;
        }
        if ($payment->status === 'success') {
            $user = $request->user()->fresh();
            $sub = $payment->subscription()->with('plan')->first();
            $data['subscription'] = $sub ? new SubscriptionResource($sub) : null;
            $data['user_coins'] = (int) $user->coins;
        }

        return $this->ok($data, null, 201);
    }

    /** GET /payments/{reference} — status polling (owner only). */
    public function show(Request $request, string $reference): JsonResponse
    {
        $payment = Payment::with('plan')->where('reference', $reference)
            ->where('user_id', $request->user()->id)->firstOrFail();

        if ($payment->status === 'pending') {
            try {
                $this->payments->apply($payment, $this->manager->forPayment($payment)->verify($payment));
                $payment = $payment->fresh(['plan']);
            } catch (InvalidArgumentException $e) {
                Log::warning('[payments] verify failed: '.$e->getMessage());
            }
        }

        return $this->ok(new PaymentResource($payment));
    }

    /** POST /payments/callback/{provider} — public webhook. */
    public function callback(Request $request, string $provider): JsonResponse
    {
        try {
            $gateway = $this->manager->driver($provider);
        } catch (InvalidArgumentException) {
            return response()->json(['message' => 'Unknown payment provider.', 'code' => 'unknown_provider'], 404);
        }

        $payment = $gateway->handleCallback($request);
        if ($payment && $payment->status === 'success') {
            $payment = $this->payments->fulfill($payment);
        }

        return $this->ok([
            'received' => true,
            'provider' => $provider,
            'reference' => $payment?->reference,
            'status' => $payment?->status,
        ]);
    }
}
