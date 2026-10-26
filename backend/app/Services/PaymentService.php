<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\AuditLog;
use App\Models\Payment;
use App\Models\PaymentMethod;
use App\Models\Plan;
use App\Models\Refund;
use App\Models\Setting;
use App\Models\Subscription;
use App\Models\User;
use App\Payments\GatewayResponse;
use App\Payments\PaymentManager;
use Illuminate\Support\Facades\DB;

/**
 * Scope §07 flow: choose package → secure provider → server verification → coins/VIP → receipt and transaction record.
 */
class PaymentService
{
    public function __construct(protected PaymentManager $manager, protected CoinLedger $coins) {}

    /**
     * Create a pending payment, hand it to the gateway and apply the outcome.
     * With an idempotency key, retrying the same checkout returns the original payment instead of charging again.
     *
     * @return array{0: Payment, 1: GatewayResponse|null}
     */
    public function checkout(User $user, Plan $plan, PaymentMethod $method, ?string $phone = null, array $data = [], ?string $idempotencyKey = null): array
    {
        if ($idempotencyKey) {
            $existing = Payment::with('plan')->where('user_id', $user->id)->where('idempotency_key', $idempotencyKey)->first();
            if ($existing) {
                return [$existing, null];
            }
        }
        if (! $method->isAvailable()) {
            throw new ApiException('Njia hii ya malipo bado haijaunganishwa. Chagua njia nyingine.', 'method_unavailable', 422);
        }

        $gateway = $this->manager->forMethod($method->code);

        $payment = Payment::create([
            'user_id' => $user->id,
            'plan_id' => $plan->id,
            'payment_method_code' => $method->code,
            'reference' => Payment::newReference(),
            'idempotency_key' => $idempotencyKey,
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
     * Mark a payment successful and deliver what was bought. Idempotent: provider callbacks may arrive more than once.
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
            $payment->receipt_number ??= 'RCT-'.now()->format('Ymd').'-'.str_pad((string) $payment->id, 6, '0', STR_PAD_LEFT);
            $feePercent = (float) PaymentMethod::where('code', $payment->payment_method_code)->value('fee_percent');
            $payment->fee_amount = (int) round($payment->amount * $feePercent / 100);

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
                    if ((int) $plan->coins > 0) {
                        $this->coins->credit($user, (int) $plan->coins, 'purchase', ['payment_id' => $payment->id], $plan->name);
                    }
                    if ((int) $plan->bonus_coins > 0) {
                        $this->coins->credit($user, (int) $plan->bonus_coins, 'bonus', ['payment_id' => $payment->id], "Bonasi: {$plan->name}");
                    }
                }
            }

            $meta['fulfilled'] = true;
            $meta['fulfilled_at'] = now()->toIso8601String();
            $payment->meta = $meta;
            $payment->save();

            return $payment;
        });
    }

    /**
     * Record a refund (the money itself is returned through the provider's dashboard until refunds are integrated).
     * A full refund also takes back what was delivered: VIP / episode pack ends, unspent purchased coins are removed.
     */
    public function refund(Payment $payment, User $staff, ?int $amount, string $reason): Payment
    {
        return DB::transaction(function () use ($payment, $staff, $amount, $reason) {
            /** @var Payment $payment */
            $payment = Payment::whereKey($payment->id)->lockForUpdate()->first();
            if ($payment->status !== 'success') {
                throw new ApiException('Malipo yaliyofanikiwa pekee ndiyo yanaweza kurejeshwa.', 'not_refundable', 422);
            }
            $remaining = (int) $payment->amount - (int) $payment->refunded_amount;
            $amount ??= $remaining;
            if ($amount <= 0 || $amount > $remaining) {
                throw new ApiException('Kiasi cha kurejesha si sahihi (kinachoweza kurejeshwa: '.$remaining.').', 'invalid_amount', 422);
            }

            Refund::create(['payment_id' => $payment->id, 'amount' => $amount, 'reason' => $reason, 'status' => 'completed', 'processed_by' => $staff->id]);
            $payment->refunded_amount = (int) $payment->refunded_amount + $amount;
            $payment->refunded_at = now();

            $full = $payment->refunded_amount >= $payment->amount;
            if ($full) {
                $payment->status = 'refunded';
                $payment->subscription()->update(['status' => 'cancelled']);
                $plan = $payment->plan;
                if ($plan?->type === 'coins' && $payment->user) {
                    $granted = (int) $plan->coins + (int) $plan->bonus_coins;
                    $this->coins->debit($payment->user, $granted, 'refund', ['payment_id' => $payment->id, 'actor_id' => $staff->id],
                        "Refund {$payment->reference}", clamp: true);
                }
            }
            $payment->save();

            AuditLog::record('payment.refund', $payment, ['amount' => $amount, 'full' => $full, 'reason' => $reason],
                "{$payment->reference}: TSh ".number_format($amount));

            return $payment;
        });
    }

    /**
     * Receipt for a successful (or refunded) payment.
     *
     * @return array<string,mixed>
     */
    public function receipt(Payment $payment): array
    {
        $payment->loadMissing(['plan', 'user', 'subscription']);
        $plan = $payment->plan;
        $delivered = match ($plan?->type) {
            'coins' => 'Coins '.number_format((int) $plan->coins + (int) $plan->bonus_coins),
            'episodes' => 'Episode '.(int) $plan->episode_quota.' za kufungua',
            'weekly', 'monthly', 'yearly' => 'VIP'.($payment->subscription?->ends_at ? ' hadi '.$payment->subscription->ends_at->format('d/m/Y') : ''),
            default => null,
        };

        return [
            'receipt_number' => $payment->receipt_number,
            'reference' => $payment->reference,
            'provider_reference' => $payment->provider_reference,
            'status' => $payment->status,
            'issued_at' => ($payment->paid_at ?? $payment->created_at)?->toIso8601String(),
            'customer' => ['name' => $payment->user?->name, 'email' => $payment->user?->email, 'phone' => $payment->phone ?? $payment->user?->phone],
            'item' => ['name' => $plan?->name, 'type' => $plan?->type, 'description' => $plan?->description, 'delivered' => $delivered],
            'payment_method' => ['code' => $payment->payment_method_code, 'name' => $payment->method?->name ?? $payment->payment_method_code],
            'amount' => (int) $payment->amount,
            'refunded_amount' => (int) $payment->refunded_amount,
            'currency' => $payment->currency,
            'seller' => ['name' => Setting::get('platform_name', 'Afriva'), 'email' => Setting::get('support_email')],
        ];
    }
}
