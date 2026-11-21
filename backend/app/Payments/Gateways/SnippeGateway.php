<?php

namespace App\Payments\Gateways;

use App\Models\Payment;
use App\Payments\Contracts\PaymentGateway;
use App\Payments\GatewayResponse;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

/**
 * Snippe (https://snippe.sh): one aggregator for Tanzanian mobile money (USSD push, the customer enters
 * their PIN on their own phone) and cards (hosted page; card numbers never reach this API).
 *
 * API: POST /v1/payments, GET /v1/payments/{reference}; Bearer API key; amounts in whole TZS.
 * Webhooks: X-Webhook-Timestamp + X-Webhook-Signature = hex HMAC-SHA256(secret, "{timestamp}.{raw body}").
 */
class SnippeGateway implements PaymentGateway
{
    /** Webhooks older than this are rejected (replay protection). */
    public const MAX_WEBHOOK_AGE = 300;

    public function __construct(protected array $config = []) {}

    public function isConnected(): bool
    {
        return filled($this->config['api_key'] ?? null);
    }

    /** Cards are paid on Snippe's hosted page, so checkout needs no card details from the viewer. */
    public function hostedCards(): bool
    {
        return true;
    }

    public function initiate(Payment $payment, array $data): GatewayResponse
    {
        $isCard = $payment->method?->type === 'card';
        $user = $payment->user;
        $phone = '+'.ltrim((string) ($payment->phone ?: $user?->phone), '+');

        $body = [
            'payment_type' => $isCard ? 'card' : 'mobile',
            'phone_number' => $phone,
            'customer' => $this->customer($payment, $isCard),
            'webhook_url' => rtrim((string) config('payments.callback_base_url'), '/').'/snippe',
            'metadata' => ['afriva_reference' => $payment->reference, 'plan_id' => (string) $payment->plan_id],
        ];
        $body['details'] = ['amount' => (int) $payment->amount, 'currency' => $payment->currency ?: 'TZS'];
        if ($isCard) {
            $return = rtrim((string) config('payments.return_url'), '/');
            $body['details']['redirect_url'] = $return.'?payment='.$payment->reference;
            $body['details']['cancel_url'] = $return.'?payment='.$payment->reference.'&cancelled=1';
        }

        try {
            $res = $this->http()->withHeaders(['Idempotency-Key' => Str::limit($payment->reference, 30, '')])
                ->post('/v1/payments', $body);
        } catch (Throwable $e) {
            Log::error("[payments] snippe initiate {$payment->reference}: ".$e->getMessage());

            return GatewayResponse::failed(__('payments.provider_error'));
        }

        if (! $res->successful()) {
            Log::warning("[payments] snippe initiate {$payment->reference} HTTP {$res->status()}: ".$res->json('error_code', ''));

            return GatewayResponse::failed($res->json('message') ?: __('payments.provider_error'));
        }

        $p = (array) $res->json('data', []);
        $reference = $p['reference'] ?? null;
        $mapped = $this->mapStatus($p['status'] ?? 'pending', $reference, $p);
        if (! $mapped->isPending()) {
            return $mapped;
        }
        if ($isCard) {
            $url = $p['payment_url'] ?? null;

            return $url
                ? GatewayResponse::pending(__('payments.redirecting'), 'redirect', $url, $reference, $p)
                : GatewayResponse::failed(__('payments.provider_error'));
        }

        return GatewayResponse::pending(__('payments.pending'), 'await_ussd', null, $reference, $p);
    }

    public function verify(Payment $payment): GatewayResponse
    {
        if (! $payment->provider_reference) {
            return GatewayResponse::pending(__('payments.pending'));
        }
        try {
            $res = $this->http()->get('/v1/payments/'.rawurlencode($payment->provider_reference));
        } catch (Throwable $e) {
            return GatewayResponse::pending(__('payments.pending'));
        }
        if (! $res->successful()) {
            return GatewayResponse::pending(__('payments.pending'));
        }
        $p = (array) $res->json('data', []);

        return $this->mapStatus($p['status'] ?? 'pending', $payment->provider_reference, $p);
    }

    public function handleCallback(Request $request): ?Payment
    {
        $raw = $request->getContent();
        if (! $this->validSignature($raw, $request->header('X-Webhook-Timestamp'), $request->header('X-Webhook-Signature'))) {
            Log::warning('[payments] snippe webhook rejected: bad or missing signature');

            return null;
        }

        $event = json_decode($raw, true) ?: [];
        $type = (string) ($event['type'] ?? '');
        $data = (array) ($event['data'] ?? []);
        if (! str_starts_with($type, 'payment.') || empty($data['reference'])) {
            return null;
        }

        $payment = Payment::where('provider_reference', $data['reference'])->first();
        if (! $payment && ! empty($data['metadata']['afriva_reference'])) {
            $payment = Payment::where('reference', $data['metadata']['afriva_reference'])->first();
        }
        if (! $payment || $payment->status !== 'pending') {
            return $payment;
        }
        // Never trust a webhook amount that differs from what was charged.
        if (isset($data['amount']['value']) && (int) $data['amount']['value'] !== (int) $payment->amount) {
            Log::warning("[payments] snippe webhook amount mismatch for {$payment->reference}");

            return null;
        }

        $status = match ($type) {
            'payment.completed' => 'success',
            'payment.failed', 'payment.expired' => 'failed',
            'payment.voided' => 'cancelled',
            default => null,
        };
        if ($status) {
            $payment->provider_reference ??= $data['reference'];
            $payment->status = $status;
            $meta = $payment->meta ?? [];
            if (! empty($data['failure_reason'])) {
                $meta['gateway_message'] = (string) $data['failure_reason'];
            }
            $payment->meta = $meta;
            $payment->save();
        }

        return $payment;
    }

    public function validSignature(string $raw, ?string $timestamp, ?string $signature): bool
    {
        $secret = (string) ($this->config['webhook_secret'] ?? '');
        if ($secret === '' || ! $timestamp || ! $signature || ! ctype_digit($timestamp)) {
            return false;
        }
        if (abs(time() - (int) $timestamp) > self::MAX_WEBHOOK_AGE) {
            return false;
        }

        return hash_equals(hash_hmac('sha256', $timestamp.'.'.$raw, $secret), strtolower(trim($signature)));
    }

    protected function mapStatus(string $status, ?string $reference, array $raw): GatewayResponse
    {
        return match ($status) {
            'completed' => GatewayResponse::success('', $reference, $raw),
            'failed', 'expired' => GatewayResponse::failed((string) ($raw['failure_reason'] ?? __('payments.failed')), $raw),
            'voided' => new GatewayResponse(GatewayResponse::FAILED, __('payments.failed'), 'none', null, $reference, $raw),
            default => GatewayResponse::pending(__('payments.pending'), 'none', null, $reference, $raw),
        };
    }

    /** @return array<string,string> */
    protected function customer(Payment $payment, bool $isCard): array
    {
        $user = $payment->user;
        $parts = preg_split('/\s+/', trim((string) ($user?->name ?: 'Afriva Customer'))) ?: ['Afriva'];
        $first = array_shift($parts) ?: 'Afriva';
        $last = $parts ? implode(' ', $parts) : $first;
        $customer = [
            'firstname' => $first,
            'lastname' => $last,
            // Snippe requires an email; phone-only accounts get a non-routable address on our own domain.
            'email' => $user?->email ?: 'customer-'.$payment->user_id.'@afriva.co.tz',
        ];
        if ($isCard) {
            $customer['country'] = 'TZ';
        }

        return $customer;
    }

    protected function http(): PendingRequest
    {
        return Http::baseUrl(rtrim((string) ($this->config['base_url'] ?? 'https://api.snippe.sh'), '/'))
            ->withToken((string) ($this->config['api_key'] ?? ''))
            ->withHeaders(['Snippe-Version' => (string) ($this->config['api_version'] ?? '2026-01-25')])
            ->acceptJson()
            ->asJson()
            ->timeout(20)
            ->connectTimeout(8);
    }
}
