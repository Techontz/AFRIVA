<?php

namespace App\Services;

use App\Models\Payment;
use App\Models\Plan;
use App\Models\Subscription;
use App\Models\User;
use App\Payments\GatewayResponse;
use App\Payments\PaymentManager;
use Illuminate\Support\Facades\DB;

class PaymentService
{
    public function __construct(protected PaymentManager $manager) {}

    /**
     * Create a pending payment, hand it to the gateway and apply the outcome.
     *
     * @return array{0: Payment, 1: GatewayResponse}
     */
    public function checkout(User $user, Plan $plan, string $methodCode, ?string $phone = null, array $data = []): array
    {
        $gateway = $this->manager->forMethod($methodCode);

        $payment = Payment::create([
            'user_id' => $user->id,
            'plan_id' => $plan->id,
            'payment_method_code' => $methodCode,
            'reference' => Payment::newReference(),
            'amount' => $plan->price,
            'currency' => $plan->currency ?: 'TZS',
            'phone' => $phone,
            'status' => 'pending',
            'meta' => ['driver' => $this->manager->keyOf($gateway), 'plan_type' => $plan->type],
        ]);

        $response = $gateway->initiate($payment, array_merge($data, ['phone' => $phone]));
        $this->apply($payment, $response);

        return [$payment->fresh(['plan']), $response];
    }

    /** Apply a gateway response to a payment (fulfilling it on success). */
    public function apply(Payment $payment, GatewayResponse $response): Payment
    {
        if ($response->providerReference && ! $payment->provider_reference) {
            $payment->provider_reference = $response->providerReference;
        }

        if ($response->isSuccessful()) {
            $payment->save();

            return $this->fulfill($payment);
        }

        if ($response->isFailed() && $payment->status === 'pending') {
            $payment->status = 'failed';
        }
        $meta = $payment->meta ?? [];
        $meta['gateway_message'] = $response->message;
        $payment->meta = $meta;
        $payment->save();

        return $payment;
    }

    /**
     * Mark a payment successful and deliver what was bought. Idempotent.
     */
    public function fulfill(Payment $payment): Payment
    {
        return DB::transaction(function () use ($payment) {
            /** @var Payment $payment */
            $payment = Payment::whereKey($payment->id)->lockForUpdate()->first();
            $meta = $payment->meta ?? [];
            if (! empty($meta['fulfilled'])) {
                return $payment;
            }

            $payment->status = 'success';
            $payment->paid_at ??= now();

            $plan = $payment->plan;
            $user = $payment->user;

            if ($plan && $user) {
                if ($plan->isTimeBased()) {
                    $current = $user->subscriptions()->timeBased()->current()->orderByDesc('ends_at')->first();
                    $start = ($current && $current->ends_at && $current->ends_at->isFuture()) ? $current->ends_at->copy() : now();
                    $days = $plan->duration_days ?: ['weekly' => 7, 'monthly' => 30, 'yearly' => 365][$plan->type];
                    Subscription::create([
                        'user_id' => $user->id,
                        'plan_id' => $plan->id,
                        'payment_id' => $payment->id,
                        'type' => $plan->type,
                        'starts_at' => $start,
                        'ends_at' => $start->copy()->addDays($days),
                        'status' => 'active',
                    ]);
                } elseif ($plan->type === 'episodes') {
                    Subscription::create([
                        'user_id' => $user->id,
                        'plan_id' => $plan->id,
                        'payment_id' => $payment->id,
                        'type' => 'episodes',
                        'starts_at' => now(),
                        'ends_at' => null,
                        'episodes_remaining' => (int) $plan->episode_quota,
                        'status' => 'active',
                    ]);
                } elseif ($plan->type === 'coins') {
                    $user->increment('coins', (int) $plan->coins + (int) $plan->bonus_coins);
                }
            }

            $meta['fulfilled'] = true;
            $meta['fulfilled_at'] = now()->toIso8601String();
            $payment->meta = $meta;
            $payment->save();

            return $payment;
        });
    }
}
