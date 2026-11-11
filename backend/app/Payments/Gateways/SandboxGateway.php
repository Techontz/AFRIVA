<?php

namespace App\Payments\Gateways;

use App\Models\Payment;
use App\Payments\Contracts\PaymentGateway;
use App\Payments\GatewayResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * Demo gateway. With PAYMENTS_SANDBOX_AUTO_APPROVE=true every payment succeeds instantly.
 * Otherwise it stays pending until POST /api/v1/payments/callback/sandbox {reference, status} is called.
 */
class SandboxGateway implements PaymentGateway
{
    public function __construct(protected array $config = []) {}

    protected function autoApprove(): bool
    {
        return (bool) config('payments.sandbox.auto_approve');
    }

    public function initiate(Payment $payment, array $data): GatewayResponse
    {
        if ($this->autoApprove()) {
            return GatewayResponse::success(__('payments.sandbox_approved'), 'SBX-'.Str::upper(Str::random(10)));
        }

        return GatewayResponse::pending(__('payments.sandbox_pending'), 'none');
    }

    public function verify(Payment $payment): GatewayResponse
    {
        if ($payment->status === 'success') {
            return GatewayResponse::success(__('payments.sandbox_approved'), $payment->provider_reference);
        }
        if ($this->autoApprove() && $payment->status === 'pending') {
            return GatewayResponse::success(__('payments.sandbox_approved'), 'SBX-'.Str::upper(Str::random(10)));
        }

        return new GatewayResponse($payment->status === 'pending' ? GatewayResponse::PENDING : GatewayResponse::FAILED, __('payments.sandbox_status', ['status' => $payment->status]));
    }

    public function handleCallback(Request $request): ?Payment
    {
        if (! config('payments.sandbox.callbacks')) {
            return null;
        }

        $payment = Payment::where('reference', (string) $request->input('reference'))->first();
        // Never let the sandbox settle a payment that a real provider is handling.
        if (! $payment || ($payment->meta['driver'] ?? null) !== 'sandbox' || $payment->status !== 'pending') {
            return null;
        }

        $status = $request->input('status', 'success');
        $payment->status = in_array($status, ['success', 'failed', 'cancelled'], true) ? $status : 'failed';
        $payment->provider_reference = $request->input('provider_reference', 'SBX-'.Str::upper(Str::random(10)));
        $payment->save();

        return $payment;
    }
}
