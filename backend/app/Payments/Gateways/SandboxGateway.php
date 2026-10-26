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
            return GatewayResponse::success('Payment approved (sandbox)', 'SBX-'.Str::upper(Str::random(10)));
        }

        return GatewayResponse::pending('Sandbox payment pending. Confirm via the sandbox callback', 'none');
    }

    public function verify(Payment $payment): GatewayResponse
    {
        if ($payment->status === 'success') {
            return GatewayResponse::success('Payment approved (sandbox)', $payment->provider_reference);
        }
        if ($this->autoApprove() && $payment->status === 'pending') {
            return GatewayResponse::success('Payment approved (sandbox)', 'SBX-'.Str::upper(Str::random(10)));
        }

        return new GatewayResponse($payment->status === 'pending' ? GatewayResponse::PENDING : GatewayResponse::FAILED, 'Sandbox payment '.$payment->status);
    }

    public function handleCallback(Request $request): ?Payment
    {
        $payment = Payment::where('reference', (string) $request->input('reference'))->first();
        if (! $payment || $payment->status !== 'pending') {
            return $payment;
        }

        $status = $request->input('status', 'success');
        $payment->status = in_array($status, ['success', 'failed', 'cancelled'], true) ? $status : 'failed';
        $payment->provider_reference = $request->input('provider_reference', 'SBX-'.Str::upper(Str::random(10)));
        $payment->save();

        return $payment;
    }
}
