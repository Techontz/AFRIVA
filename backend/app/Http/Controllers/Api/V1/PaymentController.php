<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\CheckoutRequest;
use App\Http\Resources\PaymentResource;
use App\Http\Resources\SubscriptionResource;
use App\Models\Payment;
use App\Models\PaymentMethod;
use App\Models\Plan;
use App\Models\SavedPaymentMethod;
use App\Payments\MobileNetwork;
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
        $user = $request->user();
        $meta = [];
        $gatewayData = ['card' => null]; // card numbers are never stored or forwarded by this API

        if ($request->filled('saved_method_id') || $request->filled('channel')) {
            [$methodCode, $phone, $gatewayData, $meta] = $this->resolveChannel($request);
            $method = PaymentMethod::where('code', $methodCode)->firstOrFail();
            if (! $this->manager->isAvailable($methodCode)) {
                throw ValidationException::withMessages([
                    $method->type === 'card' ? 'card' : 'phone' => [__('payments.method_unavailable', ['method' => $method->name])],
                ]);
            }
        } else {
            // Older app builds: an explicit method code.
            $method = PaymentMethod::where('code', $request->input('payment_method'))->firstOrFail();
            if ($method->type === 'mobile_money' && ! $request->filled('phone') && ! $user->phone) {
                throw ValidationException::withMessages(['phone' => [__('payments.phone_required')]]);
            }
            $phone = $request->input('phone') ?: ($method->type === 'mobile_money' ? $user->phone : null);
        }

        [$payment, $response] = $this->payments->checkout($user, $plan, $method->code, $phone, $gatewayData, $meta);

        $message = match ($payment->status) {
            'success' => __('payments.success'),
            'failed' => $response->message ?: __('payments.failed'),
            default => __('payments.pending_not_connected'),
        };
                if ($payment->status === 'pending' && $response->message && $response->message !== __('payments.provider_not_connected')) {
            $message = $response->message;
        }
        if ($payment->status === 'pending' && $method->type === 'mobile_money' && $response->nextAction === 'await_ussd') {
            $message = __('payments.check_phone', ['phone' => $phone, 'network' => $method->name]);
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

        /**
     * Work out the method, phone and gateway data for a `channel` or saved-method checkout.
     *
     * @return array{0: string, 1: ?string, 2: array<string,mixed>, 3: array<string,mixed>}
     */
    protected function resolveChannel(CheckoutRequest $request): array
    {
        $user = $request->user();
        $save = $request->boolean('save', true);

        if ($request->filled('saved_method_id')) {
            $saved = SavedPaymentMethod::where('user_id', $user->id)->find($request->integer('saved_method_id'))
                ?? throw ValidationException::withMessages(['saved_method_id' => [__('payments.saved_not_found')]]);
            if ($saved->isExpired()) {
                throw ValidationException::withMessages(['saved_method_id' => [__('payments.card_expired')]]);
            }
            $meta = ['saved_method_id' => $saved->id];
            if ($saved->type === 'mobile_money') {
                return [MobileNetwork::methodFor($saved->phone) ?? $saved->method_code, $saved->phone, ['card' => null], $meta];
            }
            if (! $saved->provider_token && ! config('payments.sandbox.auto_approve')) {
                throw ValidationException::withMessages(['saved_method_id' => [__('payments.card_needs_details')]]);
            }

            return [$saved->method_code, null, ['card' => null, 'card_token' => $saved->provider_token], $meta];
        }

        if ($request->input('channel') === 'mobile_money') {
            $phone = MobileNetwork::normalize($request->input('phone') ?: $user->phone);
            if (! $phone) {
                throw ValidationException::withMessages(['phone' => [__('payments.phone_invalid')]]);
            }
            $code = MobileNetwork::methodFor($phone)
                ?? throw ValidationException::withMessages(['phone' => [__('payments.network_unknown')]]);
            $meta = $save ? ['save_method' => ['type' => 'mobile_money', 'method_code' => $code, 'phone' => $phone]] : [];

            return [$code, $phone, ['card' => null], $meta];
        }

        $card = $request->input('card');
        if (! is_array($card)) {
            throw ValidationException::withMessages(['card' => [__('payments.card_required')]]);
        }
        if (now()->setDate((int) $card['exp_year'], (int) $card['exp_month'], 1)->endOfMonth()->isPast()) {
            throw ValidationException::withMessages(['card.exp_month' => [__('payments.card_expired')]]);
        }
        $token = $card['token'] ?? null;
        $meta = $save ? ['save_method' => [
            'type' => 'card', 'method_code' => $card['brand'], 'card_last4' => $card['last4'],
            'card_exp_month' => (int) $card['exp_month'], 'card_exp_year' => (int) $card['exp_year'],
            'provider_token' => $token ? encrypt($token) : null,
        ]] : [];

        return [$card['brand'], null, ['card' => null, 'card_token' => $token], $meta];
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
            return response()->json(['message' => __('payments.unknown_provider'), 'code' => 'unknown_provider'], 404);
        }

        $payment = $gateway->handleCallback($request);
        // A provider may only settle payments that were routed through it.
        if ($payment && ($payment->meta['driver'] ?? null) !== $this->manager->keyOf($gateway)) {
            Log::warning("[payments] {$provider} callback ignored for {$payment->reference}: handled by another driver.");
            $payment = null;
        }
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
